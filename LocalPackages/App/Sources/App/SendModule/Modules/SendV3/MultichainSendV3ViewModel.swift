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
            refreshCommentEncryptionKey()
            updateViewState()
        }
    }

    /// The key a GRAM comment to the recipient on screen goes encrypted to, as far as it is read.
    private enum CommentEncryptionKey {
        /// No recipient whose key the comment can go encrypted to: another asset, a recipient not yet
        /// resolved, or a wallet that cannot encrypt.
        case none
        case reading(recipient: String, task: Task<Void, Never>)
        /// The recipient's key, or `nil` when it holds none.
        case read(recipient: String, key: String?)
        /// The read failed, so the key is unknown: it is read again on the next refresh.
        case unread(recipient: String)

        var key: String? {
            guard case let .read(_, key) = self else {
                return nil
            }
            return key
        }

        /// Whether the recipient's key is unknown: still being read, or its read failed.
        var isUnknown: Bool {
            switch self {
            case .reading, .unread:
                true
            case .none, .read:
                false
            }
        }

        /// Whether `recipient`'s key is read or being read, so that it is not read again.
        func covers(_ recipient: String) -> Bool {
            switch self {
            case let .reading(current, _), let .read(current, _):
                current == recipient
            case .none, .unread:
                false
            }
        }
    }

    private var comment: String?
    /// The switch under a comment that can go encrypted: off until the user turns it on.
    private var isCommentEncrypted = false
    private var commentEncryptionKey: CommentEncryptionKey = .none {
        didSet {
            if case let .reading(_, task) = oldValue {
                task.cancel()
            }
        }
    }

    private var recipientState: MultichainSendRecipientState = .empty {
        didSet {
            if case let .resolving(_, _, task) = oldValue {
                task.cancel()
            }
            refreshCommentEncryptionKey()
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
        refreshCommentEncryptionKey()
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
        Task { @MainActor [weak self] in
            guard let pasteboardString = await UIPasteboard.general.readString() else { return }
            self?.didInputRecipient(pasteboardString)
            self?.didUpdateRecipient?(pasteboardString)
        }
    }

    func didTapCommentPasteButton() {
        Task { @MainActor [weak self] in
            guard let pasteboardString = await UIPasteboard.general.readString() else { return }
            self?.didInputComment(pasteboardString)
            self?.didUpdateComment?(pasteboardString)
        }
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
        didUpdateCurrency?(isSwapped ? sendController.getCurrency().code : "")
        lastFiatInputString = nil
        didUpdateItem()
        updateViewState()
    }
}

private extension MultichainSendV3ViewModelImplementation {
    /// Whether the switch is on and the recipient's key is read.
    var isCommentEncryptedToRecipient: Bool {
        isCommentEncrypted && commentEncryptionKey.key != nil
    }

    /// Whether the switch is on screen: under a comment that can go encrypted, while the recipient holds a
    /// key, or while the switch is on and that key is unknown, so that it can be turned off.
    var showsCommentEncryption: Bool {
        let comment = comment ?? ""
        guard item.isSupportComment,
              !recipientState.isMemoRequired,
              sendController.canEncrypt(comment: comment),
              case .ok = sendController.validateComment(comment: comment)
        else {
            return false
        }
        return commentEncryptionKey.key != nil || (isCommentEncrypted && commentEncryptionKey.isUnknown)
    }

    /// Whether the comment goes encrypted: the switch is on screen and on, and the recipient's key is read.
    var encryptsComment: Bool {
        showsCommentEncryption && isCommentEncryptedToRecipient
    }

    var isEncryptedCommentTooLong: Bool {
        encryptsComment && (comment ?? "").utf8.count > sendController.maxEncryptedCommentBytes
    }

    /// Whether Continue waits: the switch is on screen and on while the recipient's key is unknown, so the
    /// comment would go as it is if sent now. Turning the switch off sends it as it is.
    var awaitsCommentEncryptionKey: Bool {
        showsCommentEncryption && isCommentEncrypted && commentEncryptionKey.isUnknown
    }

    /// Reads, once per recipient, the key a GRAM comment to the recipient on screen can go encrypted to; a
    /// read that failed is read again on the next refresh. Another asset, a recipient not yet resolved or a
    /// wallet that cannot encrypt has none.
    func refreshCommentEncryptionKey() {
        guard item.asset.asset.chain == .ton,
              item.asset.isNative,
              sendController.canEncryptComment,
              let recipient = recipientState.recipient?.address
        else {
            commentEncryptionKey = .none
            return
        }
        guard !commentEncryptionKey.covers(recipient) else {
            return
        }
        // As the recipient's resolution does: the form's state is only touched back on the main queue.
        let task = Task { [sendController] in
            let state: CommentEncryptionKey
            do {
                let key = try await sendController.commentEncryptionKey(recipient: recipient)
                state = .read(recipient: recipient, key: key)
            } catch {
                Log.send.w("comment encryption key unread", error: error)
                state = .unread(recipient: recipient)
            }
            await MainActor.run {
                // The refresh that replaces a read cancels it on the main queue: checked here, it is never applied late.
                guard !Task.isCancelled else { return }
                self.commentEncryptionKey = state
                self.updateViewState()
            }
        }
        commentEncryptionKey = .reading(recipient: recipient, task: task)
    }

    /// A comment that can go encrypted, or whose encryption is on while the recipient's key is unknown,
    /// with the link that switches its encryption under it.
    func encryptableCommentState() -> SendV3ViewModelViewState.CommentState {
        let isEncrypted = isCommentEncrypted
        let action = isEncrypted ? TKLocales.Send.Comment.decrypt : TKLocales.Send.Comment.encrypt
        let hint = isEncrypted ? TKLocales.Send.Comment.encryptedDescription : TKLocales.Send.Comment.description
        return SendV3ViewModelViewState.CommentState(
            isValid: !isEncryptedCommentTooLong,
            placeholder: TKLocales.Send.Comment.placeholder,
            description: "\(hint)\n\(action)".withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            ),
            actionItems: [
                TKActionLabel.ActionItem(text: action) { [weak self] in
                    self?.isCommentEncrypted.toggle()
                    self?.updateViewState()
                },
            ]
        )
    }

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
            && !isEncryptedCommentTooLong
            && !awaitsCommentEncryptionKey
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

        if showsCommentEncryption {
            return encryptableCommentState()
        }
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
            commentEncryptionKey: encryptsComment ? commentEncryptionKey.key : nil,
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
        commentEncryptionKey: String? = nil,
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
                commentEncryptionKey: commentEncryptionKey,
                isMaxAmount: isMaxAmount
            )
        )
    }
}
