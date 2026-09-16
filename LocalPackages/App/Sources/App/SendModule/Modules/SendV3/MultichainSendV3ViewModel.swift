import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import TronSwift
import UIKit

protocol MultichainSendV3ModuleOutput: AnyObject {
    var didContinueSend: ((SendData) -> Void)? { get set }
    var didTapPicker: ((Wallet, MultichainAsset) -> Void)? { get set }
    var didTapScan: (() -> Void)? { get set }
    var didTapClose: (() -> Void)? { get set }
}

protocol MultichainSendV3ModuleInput: AnyObject {
    func updateWithAsset(_ asset: MultichainAsset)
    func setRecipient(_ recipient: MultichainRecipient)
    func setAmount(_ amount: BigUInt)
    func setComment(_ comment: String)
}

final class MultichainSendV3ViewModelImplementation: SendV3ViewModel, MultichainSendV3ModuleOutput, MultichainSendV3ModuleInput {
    var didContinueSend: ((SendData) -> Void)?
    var didTapPicker: ((Wallet, MultichainAsset) -> Void)?
    var didTapScan: (() -> Void)?
    var didTapClose: (() -> Void)?

    var didUpdateViewState: ((SendV3ViewModelViewState) -> Void)?
    var didUpdateTitle: ((NSAttributedString?) -> Void)?
    var didUpdateRecipientPlaceholder: ((String) -> Void)?
    var didUpdateRecipient: ((String) -> Void)?
    var didUpdateAmountPlaceholder: ((String) -> Void)?
    var didUpdateAmount: ((String) -> Void)?
    var didUpdateAmountIsHidden: ((Bool) -> Void)?
    var didUpdateToken: ((TokenPickerButton.Configuration) -> Void)?
    var didUpdateCurrency: ((String) -> Void)?
    var didUpdateComment: ((String) -> Void)?
    var didShowError: ((String) -> Void)?
    let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.groupingSeparator = Locale.current.groupingSeparator ?? " "
        numberFormatter.groupingSize = 3
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.decimalSeparator = Locale.current.decimalSeparator
        numberFormatter.maximumIntegerDigits = 16
        numberFormatter.roundingMode = .down
        return SendAmountTextFieldFormatter(
            currencyFormatter: numberFormatter
        )
    }()

    private let wallet: Wallet
    private let sendController: SendV3Controller
    private let appSettingsStore: AppSettingsStore

    private var item: MultichainSendItem {
        didSet {
            didUpdateItem()
            updateViewState()
        }
    }

    private var comment: String?
    private var recipientState: MultichainSendRecipientState = .empty {
        didSet {
            if case let .resolving(_, _, task) = oldValue {
                task.cancel()
            }
            updateViewState()
        }
    }

    private var resolveGeneration: UInt64 = 0
    private var balanceDisplay = ""
    private var converted = ""
    private var isAmountValid = false
    private var isSwapped = false
    private var lastFiatInputString: String?

    init(
        wallet: Wallet,
        sendInput: MultichainSendInput,
        recipient: MultichainRecipient?,
        comment: String?,
        sendController: SendV3Controller,
        appSettingsStore: AppSettingsStore
    ) {
        self.wallet = wallet
        self.item = sendInput.item
        if let resolved = Self.recipientResolved(recipient, forItem: sendInput.item, network: wallet.network) {
            recipientState = .resolved(input: resolved.address, recipient: resolved, isMemoRequired: false)
        }
        self.comment = comment
        self.sendController = sendController
        self.appSettingsStore = appSettingsStore
    }

    /// An injected recipient may be resolved for another chain when the asset was
    /// switched in the picker; re-resolve it for the item's chain. Falls back to the
    /// stale recipient so the form still shows the address alongside its validation error.
    private static func recipientResolved(
        _ recipient: MultichainRecipient?,
        forItem item: MultichainSendItem,
        network: Network
    ) -> MultichainRecipient? {
        guard let recipient,
              let chain = item.asset.asset.chain,
              chain != recipient.chain
        else {
            return recipient
        }
        return MultichainRecipient(string: recipient.address, chain: chain, network: network) ?? recipient
    }

    func viewDidLoad() {
        didUpdateRecipientPlaceholder?(TKLocales.Send.Recepient.placeholder)
        didUpdateTitle?(TKLocales.Send.title.withTextStyle(.h3, color: .Text.primary))
        sendAmountTextFieldFormatter.maximumFractionDigits = item.fractionalDigits
        didUpdateAmountPlaceholder?(TKLocales.Send.Amount.placeholder)
        didUpdateComment?(comment ?? "")
        if !recipientState.input.isEmpty {
            didUpdateRecipient?(recipientState.input)
        }
        didUpdateCurrency?("")
        didUpdateItem()
        didUpdateAmount?(inputString(amount: item.amount, fractionDigits: item.fractionalDigits))
        updateViewState()
    }

    func updateWithAsset(_ asset: MultichainAsset) {
        isSwapped = false
        lastFiatInputString = nil
        item = item.setAsset(asset)
        sendAmountTextFieldFormatter.maximumFractionDigits = asset.asset.decimals
        didUpdateCurrency?("")
        didUpdateAmount?("")
        applyRecipientInput(recipientState.input)
    }

    func setRecipient(_ recipient: MultichainRecipient) {
        recipientState = .resolved(input: recipient.address, recipient: recipient, isMemoRequired: false)
        didUpdateRecipient?(recipient.address)
    }

    func setAmount(_ amount: BigUInt) {
        lastFiatInputString = nil
        item = item.setAmount(amount)
    }

    func setComment(_ comment: String) {
        didInputComment(comment)
        didUpdateComment?(comment)
    }

    func didInputRecipient(_ string: String) {
        guard string != recipientState.input else { return }
        applyRecipientInput(string)
    }

    func didInputAmount(_ string: String) {
        let unformatted = sendAmountTextFieldFormatter.unformatString(string) ?? ""
        if isSwapped {
            lastFiatInputString = string
            let amount = sendController.multichainTokenAmountFromCurrencyInput(
                asset: item.asset,
                currencyInput: unformatted
            )
            item = item.setAmount(amount)
        } else {
            lastFiatInputString = nil
            let amount = sendController.tokenAmountFromTokenInput(
                tokenInput: unformatted,
                fractionDigits: item.fractionalDigits
            )
            item = item.setAmount(amount)
        }
        didUpdateAmount?(string)
    }

    func didInputComment(_ string: String) {
        guard string != comment else { return }
        comment = string
        updateViewState()
    }

    func didTapWalletTokenPicker() {
        didTapPicker?(wallet, item.asset)
    }

    func didTapRecipientPasteButton() {
        guard let pasteboardString = UIPasteboard.general.string else { return }
        didInputRecipient(pasteboardString)
        didUpdateRecipient?(pasteboardString)
    }

    func didTapCommentPasteButton() {
        guard let pasteboardString = UIPasteboard.general.string else { return }
        didInputComment(pasteboardString)
        didUpdateComment?(pasteboardString)
    }

    func didTapRecipientScanButton() {
        didTapScan?()
    }

    func didTapCloseButton() {
        didTapClose?()
    }

    func didTapMax() {
        if isSwapped {
            lastFiatInputString = nil
        }
        item = item.setAmount(item.asset.balance)
    }

    func didTapSwap() {
        isSwapped.toggle()
        sendAmountTextFieldFormatter.maximumFractionDigits = isSwapped ? 2 : item.fractionalDigits
        didUpdateCurrency?(isSwapped ? "\(sendController.getCurrency())" : "")
        lastFiatInputString = nil
        didUpdateItem()
        updateViewState()
    }
}

private extension MultichainSendV3ViewModelImplementation {
    func applyRecipientInput(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            recipientState = .empty
            return
        }
        guard let chain = item.asset.asset.chain else {
            recipientState = .failed(input: string, reason: .invalidAddress)
            return
        }
        if let recipient = MultichainRecipient(string: trimmed, chain: chain, network: wallet.network) {
            recipientState = .resolved(input: string, recipient: recipient, isMemoRequired: false)
        } else if chain == .ton, wallet.network.matchesTonAddress(trimmed) {
            recipientState = resolvingState(input: string, resolveString: trimmed)
        } else {
            recipientState = .failed(input: string, reason: .invalidAddress)
        }
    }

    func resolvingState(input: String, resolveString: String) -> MultichainSendRecipientState {
        resolveGeneration += 1
        let generation = resolveGeneration
        // `item` is only safe to read here: the task below runs off the main queue, where the
        // form's state is still being mutated.
        let logInfo = [
            "chain": item.asset.asset.chain?.rawValue ?? "unknown",
            "assetId": item.asset.asset.assetId,
            "input": resolveString.pretty.masked,
        ]
        let task = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            let resolved = await resolveRecipient(resolveString, logInfo: logInfo)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard case let .resolving(_, currentGeneration, _) = self.recipientState,
                      currentGeneration == generation
                else { return }
                self.recipientState = .resolutionResult(input: input, resolved: resolved)
            }
        }
        return .resolving(input: input, generation: generation, task: task)
    }

    /// A failure here is indistinguishable from "no such name" on screen, so the reason only
    /// exists in the log.
    func resolveRecipient(_ input: String, logInfo: [String: String]) async -> LegacyRecipient? {
        do {
            return try await sendController.resolveRecipient(input: input)
        } catch {
            Log.send.failure("recipient resolution failed", error: error, extraInfo: logInfo)
            return nil
        }
    }

    func inputString(amount: BigUInt, fractionDigits: Int) -> String {
        guard amount > 0 else { return "" }
        return sendController.convertAmountToInputString(
            amount: amount,
            fractionDigits: fractionDigits
        )
    }

    func fiatInputString(for amount: BigUInt) -> String {
        guard amount > 0 else { return "" }
        let fiat = sendController.convertMultichainAmountToCurrency(
            asset: item.asset,
            amount: amount,
            showCurrency: false
        )
        return sendAmountTextFieldFormatter.unformatString(fiat) ?? ""
    }

    func didUpdateItem() {
        isAmountValid = item.amount > 0 && item.asset.balance >= item.amount
        balanceDisplay = sendController.formatMultichainBalance(
            asset: item.asset,
            isSecure: appSettingsStore.getState().isSecureMode
        )

        if isSwapped {
            converted = sendController.convertAmountToInputString(
                amount: item.amount,
                fractionDigits: item.fractionalDigits,
                symbol: item.asset.asset.symbol
            )
            didUpdateAmount?(lastFiatInputString ?? fiatInputString(for: item.amount))
        } else {
            converted = sendController.convertMultichainAmountToCurrency(
                asset: item.asset,
                amount: item.amount
            )
            didUpdateAmount?(inputString(amount: item.amount, fractionDigits: item.fractionalDigits))
        }
        updateTokenButton()
    }

    func updateTokenButton() {
        let (image, _) = AssetIdResolver.tkImageSource(
            for: item.asset.asset.assetId,
            imageUrl: URL(string: item.asset.asset.image),
            multichainEnabled: true
        )

        let networkIcon = item.asset.isNative ? nil : item.asset.asset.chain?.tokenIcon20
        didUpdateToken?(
            TokenPickerButton.Configuration(
                name: item.asset.asset.symbol,
                image: image,
                networkIcon: networkIcon
            )
        )
    }

    func updateViewState() {
        let recipientValidation = validateRecipient()
        let limitError: String? = nil
        let balanceState = SendV3ViewModelViewState.BalanceState(
            converted: converted,
            remaining: balanceStateRemaining(),
            limitError: limitError
        )

        let isRequiredCommentEmpty = item.isSupportComment
            && recipientState.isMemoRequired
            && (comment ?? "").isEmpty

        var configuration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        configuration.isEnabled = recipientValidation.isValid
            && recipientValidation.isNotEmpty
            && isAmountValid
            && !isRequiredCommentEmpty
        configuration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.continueAction))
        configuration.action = { [weak self] in
            self?.continueAction()
        }

        let viewState = SendV3ViewModelViewState(
            isRecipientValid: recipientValidation.isValid,
            recipientDescription: recipientValidation.description,
            balanceState: balanceState,
            continueButtonConfiguration: configuration,
            commentState: commentState(),
            isTokenPickerEnabled: true,
            isSwapVisible: true
        )
        didUpdateViewState?(viewState)
    }

    func balanceStateRemaining() -> SendV3ViewModelViewState.BalanceState.Remaining {
        if item.amount > item.asset.balance {
            return .insufficient
        }
        return .balance(balanceDisplay)
    }

    func validateRecipient() -> (
        isValid: Bool,
        isNotEmpty: Bool,
        description: SendV3ViewModelViewState.RecipientDescription?
    ) {
        switch recipientState.validation(
            expectedChain: item.asset.asset.chain,
            forbiddenSelfSendAddress: forbiddenSelfSendAddress()
        ) {
        case .empty, .resolving:
            return (true, false, nil)
        case .valid:
            return (true, true, nil)
        case .chainMismatch:
            return (false, true, incorrectRecipientDescription())
        case .invalidAddress:
            return (false, false, incorrectRecipientDescription())
        case .scam:
            return (false, false, scamRecipientDescription())
        case .selfSendForbidden:
            return (false, true, selfSendForbiddenDescription())
        }
    }

    func forbiddenSelfSendAddress() -> String? {
        item.forbiddenSelfSendAddress(wallet: wallet)
    }

    func selfSendForbiddenDescription() -> SendV3ViewModelViewState.RecipientDescription {
        SendV3ViewModelViewState.RecipientDescription(
            description: TKLocales.Send.trxSelfSendForbidden.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            ),
            actionItems: []
        )
    }

    func scamRecipientDescription() -> SendV3ViewModelViewState.RecipientDescription {
        SendV3ViewModelViewState.RecipientDescription(
            description: TKLocales.Send.scamAddress.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            ),
            actionItems: []
        )
    }

    func incorrectRecipientDescription() -> SendV3ViewModelViewState.RecipientDescription {
        return SendV3ViewModelViewState.RecipientDescription(
            description: SendMultichainRecipientErrorFormatter.invalidAddressDescription(
                selectedChain: item.asset.asset.chain
            ).withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            ),
            actionItems: []
        )
    }

    func commentState() -> SendV3ViewModelViewState.CommentState? {
        guard item.isSupportComment else { return nil }

        let isCommentRequired = recipientState.isMemoRequired
        let comment = comment ?? ""
        let isCommentOk = sendController.validateComment(comment: comment)
        switch (isCommentRequired, comment.isEmpty, isCommentOk) {
        case (_, false, .ledgerNonAsciiError):
            return SendV3ViewModelViewState.CommentState(
                isValid: false,
                placeholder: TKLocales.Send.Comment.placeholder,
                description: TKLocales.Send.Comment.asciiError.withTextStyle(
                    .body2,
                    color: .Accent.red,
                    alignment: .left,
                    lineBreakMode: .byWordWrapping
                )
            )
        case (false, true, _):
            return SendV3ViewModelViewState.CommentState(
                isValid: true,
                placeholder: TKLocales.Send.Comment.placeholder,
                description: nil
            )
        case (false, false, _):
            return SendV3ViewModelViewState.CommentState(
                isValid: true,
                placeholder: TKLocales.Send.Comment.placeholder,
                description: TKLocales.Send.Comment.description.withTextStyle(
                    .body2,
                    color: .Text.secondary,
                    alignment: .left,
                    lineBreakMode: .byWordWrapping
                )
            )
        case (true, true, _):
            return SendV3ViewModelViewState.CommentState(
                isValid: false,
                placeholder: TKLocales.Send.RequiredComment.placeholder,
                description: TKLocales.Send.RequiredComment.description.withTextStyle(
                    .body2,
                    color: .Accent.orange,
                    alignment: .left,
                    lineBreakMode: .byWordWrapping
                )
            )
        case (true, false, _):
            return SendV3ViewModelViewState.CommentState(
                isValid: true,
                placeholder: TKLocales.Send.RequiredComment.placeholder,
                description: TKLocales.Send.RequiredComment.description.withTextStyle(
                    .body2,
                    color: .Accent.orange,
                    alignment: .left,
                    lineBreakMode: .byWordWrapping
                )
            )
        }
    }

    func continueAction() {
        guard let data = SendData.multichainSendData(
            wallet: wallet,
            recipient: recipientState.recipient,
            item: item,
            comment: item.isSupportComment ? comment : nil,
            isMaxAmount: item.asset.balance > 0 && item.amount == item.asset.balance
        ) else {
            Log.send.w(
                "continue blocked - no resolved recipient",
                extraInfo: [
                    "chain": item.asset.asset.chain?.rawValue ?? "unknown",
                    "assetId": item.asset.asset.assetId,
                    "validation": "\(recipientState.validation(expectedChain: item.asset.asset.chain, forbiddenSelfSendAddress: forbiddenSelfSendAddress()))",
                ]
            )
            return
        }
        didContinueSend?(data)
    }
}

extension SendData {
    static func multichainSendData(
        wallet: Wallet,
        recipient: MultichainRecipient?,
        item: MultichainSendItem,
        comment: String?,
        isMaxAmount: Bool
    ) -> SendData? {
        guard let recipient else { return nil }
        return .multichain(
            MultichainSendData(
                wallet: wallet,
                recipient: recipient,
                asset: item.asset,
                amount: item.amount,
                comment: comment,
                isMaxAmount: isMaxAmount
            )
        )
    }
}
