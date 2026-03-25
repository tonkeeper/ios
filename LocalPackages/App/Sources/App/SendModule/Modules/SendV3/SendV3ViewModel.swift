import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

protocol SendV3ModuleOutput: AnyObject {
    var didContinueSend: ((SendData) -> Void)? { get set }
    var didTapPicker: ((Wallet, SendV3Item) -> Void)? { get set }
    var didTapScan: (() -> Void)? { get set }
    var didTapClose: (() -> Void)? { get set }
    var didOpenURL: ((URL) -> Void)? { get set }
}

protocol SendV3ModuleInput: AnyObject {
    func updateWithToken(_ token: SendV3Item)
    func setRecipient(string: String)
    func setAmount(amount: BigUInt?)
    func setComment(comment: String?)
}

protocol SendV3ViewModel: AnyObject {
    var didUpdateViewState: ((SendV3ViewModelViewState) -> Void)? { get set }
    var didUpdateTitle: ((NSAttributedString?) -> Void)? { get set }
    var didUpdateRecipientPlaceholder: ((String) -> Void)? { get set }
    var didUpdateRecipient: ((String) -> Void)? { get set }
    var didUpdateAmountPlaceholder: ((String) -> Void)? { get set }
    var didUpdateAmount: ((String) -> Void)? { get set }
    var didUpdateAmountIsHidden: ((Bool) -> Void)? { get set }
    var didUpdateToken: ((TokenPickerButton.Configuration) -> Void)? { get set }
    var didUpdateCurrency: ((String) -> Void)? { get set }
    var didUpdateComment: ((String) -> Void)? { get set }
    var didShowError: ((String) -> Void)? { get set }

    var sendAmountTextFieldFormatter: SendAmountTextFieldFormatter { get }

    func viewDidLoad()
    func didInputRecipient(_ string: String)
    func didInputAmount(_ string: String)
    func didInputComment(_ string: String)
    func didTapWalletTokenPicker()
    func didTapRecipientPasteButton()
    func didTapCommentPasteButton()
    func didTapRecipientScanButton()
    func didTapCloseButton()
    func didTapMax()
    func didTapSwap()
}

struct SendV3ViewModelViewState {
    struct BalanceState {
        enum Remaining {
            case insufficient
            case remaining(String)
        }

        let converted: String
        let remaining: Remaining
        let limitError: String?
    }

    struct CommentState {
        let isValid: Bool
        let placeholder: String
        let description: NSAttributedString?
    }

    struct RecipientDescription {
        let description: NSAttributedString
        let actionItems: [TKActionLabel.ActionItem]
    }

    let isRecipientValid: Bool
    let recipientDescription: RecipientDescription?
    let balanceState: BalanceState
    let continueButtonConfiguration: TKButton.Configuration
    let commentState: CommentState?
    let isTokenPickerEnabled: Bool
    let isSwapVisible: Bool
}

final class SendV3ViewModelImplementation: SendV3ViewModel, SendV3ModuleOutput, SendV3ModuleInput {
    // MARK: - SendV3ModuleOutput

    var didContinueSend: ((SendData) -> Void)?
    var didTapPicker: ((Wallet, SendV3Item) -> Void)?
    var didTapScan: (() -> Void)?
    var didTapClose: (() -> Void)?
    var didOpenURL: ((URL) -> Void)?

    // MARK: - SendV3ModuleInput

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

    func updateWithToken(_ token: SendV3Item) {
        if case .withdraw = sendInput { return }
        self.item = token
        lastFiatInputString = nil
        isSwapped = false
        didUpdateCurrency?("")
        didUpdateAmount?("0")
        didUpdateItem()
        updateViewState()
    }

    func setRecipient(string: String) {
        didInputRecipient(string)
        didUpdateRecipient?(string)
    }

    func setAmount(amount: BigUInt?) {
        item = item.setAmount(amount: amount ?? 0)
    }

    func setComment(comment: String?) {
        didInputComment(comment ?? "")
        didUpdateComment?(comment ?? "")
    }

    // MARK: - View State

    private var viewState: SendV3ViewModelViewState? {
        didSet {
            guard let viewState else { return }
            didUpdateViewState?(viewState)
        }
    }

    // MARK: - State

    private var comment: String?
    private var sendInput: SendInput
    private var item: SendV3Item {
        didSet {
            didUpdateItem()
            updateViewState()
        }
    }

    private var recipient: Recipient?
    private var recipientInput = ""
    private var remaining = SendV3Controller.Remaining.remaining("")
    private var converted = ""
    private var isAmountValid = false
    private var isSwapped = false
    private var recipientResolvingTask: Task<Void, Never>?
    private var lastFiatInputString: String?
    private var tronSwapTitle: String = ""
    private var isProcessingExchange = false

    // MARK: - Formatters

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

    // MARK: - Dependencies

    private let wallet: Wallet
    private let sendController: SendV3Controller
    private let balanceStore: ConvertedBalanceStore
    private let appSettingsStore: AppSettingsStore
    private let buySellMethodsService: BuySellMethodsService
    private let onRampService: OnRampService
    private let configuration: Configuration

    // MARK: - Init

    init(
        wallet: Wallet,
        sendInput: SendInput,
        recipient: Recipient?,
        comment: String?,
        sendController: SendV3Controller,
        balanceStore: ConvertedBalanceStore,
        appSettingsStore: AppSettingsStore,
        buySellMethodsService: BuySellMethodsService,
        onRampService: OnRampService,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.comment = comment
        self.sendInput = sendInput
        self.recipient = recipient
        self.sendController = sendController
        self.balanceStore = balanceStore
        self.appSettingsStore = appSettingsStore
        self.buySellMethodsService = buySellMethodsService
        self.onRampService = onRampService
        self.configuration = configuration

        switch sendInput {
        case let .direct(item):
            self.item = item
        case let .withdraw(sourceAsset, _):
            self.item = Self.resolveItem(from: sourceAsset, wallet: wallet, balanceStore: balanceStore) ?? .ton(.token(.ton, amount: 0))
        }
    }

    func viewDidLoad() {
        balanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateConvertedBalance(wallet):
                guard observer.wallet == wallet else { return }
                DispatchQueue.main.async {
                    observer.recalculateOnBalanceUpdate()
                }
            }
        }

        switch sendInput {
        case .direct:
            didUpdateRecipientPlaceholder?(TKLocales.Send.Recepient.placeholder)
            didUpdateTitle?(TKLocales.Send.title.withTextStyle(.h3, color: .Text.primary))
        case let .withdraw(_, exchangeTo):
            let networkLabel = RampItemConfigurator.networkLabel(network: exchangeTo.network, networkName: exchangeTo.networkName)

            didUpdateRecipientPlaceholder?("\(exchangeTo.symbol) \(networkLabel) \(TKLocales.Send.Recepient.address)")
            let mainPart = "\(TKLocales.Send.title) \(exchangeTo.symbol) ".withTextStyle(.h3, color: .Text.primary)
            let networkPart = networkLabel.uppercased().withTextStyle(.h3, color: .Text.secondary)
            let titleAttributed = NSMutableAttributedString(attributedString: mainPart)
            titleAttributed.append(networkPart)
            didUpdateTitle?(titleAttributed)
        }

        sendAmountTextFieldFormatter.maximumFractionDigits = item.fractionalDigits
        didUpdateItem()
        didUpdateAmountPlaceholder?(TKLocales.Send.Amount.placeholder)
        didUpdateComment?(comment ?? "")
        if let recipient {
            didUpdateRecipient?(recipient.stringValue)
        }
        updateViewState()
        didUpdateAmount?(sendController.convertAmountToInputString(amount: item.amount, fractionDigits: item.fractionalDigits))

        if case let .ton(ton) = item, case .nft = ton {
            didUpdateAmountIsHidden?(true)
        }

        tronSwapTitle = configuration.value(\.tronSwapTitle)
    }

    func didInputRecipient(_ string: String) {
        guard string != recipientInput else { return }
        recipientInput = string
        recipient = nil
        recipientResolvingTask?.cancel()
        recipientResolvingTask = nil

        guard !string.isEmpty else {
            updateViewState()
            return
        }

        if case .withdraw = sendInput {
            updateViewState()
            return
        }

        recipientResolvingTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            do {
                guard !Task.isCancelled else { return }
                let recipient = try await sendController.resolveRecipient(input: string)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.recipient = recipient
                    self.recipientResolvingTask = nil
                    self.updateViewState()
                }
            } catch {
                await MainActor.run {
                    self.recipient = nil
                    self.recipientResolvingTask = nil
                    self.updateViewState()
                }
            }
        }

        updateViewState()
    }

    func didInputComment(_ string: String) {
        guard string != comment else { return }
        comment = string
        updateViewState()
    }

    func didInputAmount(_ string: String) {
        let unformatted = sendAmountTextFieldFormatter.unformatString(string) ?? ""

        if isSwapped {
            lastFiatInputString = string
            switch item {
            case let .ton(ton):
                switch ton {
                case .nft: break
                case let .token(token, _):
                    let tokenAmount = sendController.tokenAmountFromCurrencyInput(
                        token: token,
                        currencyInput: unformatted
                    )
                    item = item.setAmount(amount: tokenAmount)
                }
            case let .tron(tron):
                switch tron {
                case .usdt:
                    let tokenAmount = sendController.tronUSDTAmountFromCurrencyInput(currencyInput: unformatted)
                    item = item.setAmount(amount: tokenAmount)
                }
            }
        } else {
            lastFiatInputString = nil
            let tokenAmount = sendController.tokenAmountFromTokenInput(
                tokenInput: unformatted,
                fractionDigits: item.fractionalDigits
            )
            item = item.setAmount(amount: tokenAmount)
        }

        didUpdateAmount?(string)
    }

    func didTapWalletTokenPicker() {
        if case .withdraw = sendInput { return }
        didTapPicker?(wallet, item)
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
        switch item {
        case let .ton(ton):
            switch ton {
            case .nft: break
            case let .token(token, _):
                let maxAmount = sendController.getMaximumAmount(token: token)
                item = item.setAmount(amount: maxAmount)
            }
        case let .tron(tron):
            switch tron {
            case .usdt:
                let maxAmount = sendController.getTronUSDTMaximumAmount()
                item = item.setAmount(amount: maxAmount)
            }
        }
    }

    func didTapSwap() {
        if case .withdraw = sendInput { return }
        isSwapped.toggle()
        sendAmountTextFieldFormatter.maximumFractionDigits = isSwapped ? 2 : item.fractionalDigits

        let amount = item.amount
        let formatted: String
        let converted: String

        switch item {
        case let .ton(ton):
            switch ton {
            case .nft:
                formatted = ""
                converted = ""
            case let .token(token, _):
                if isSwapped {
                    if let lastFiatInputString {
                        formatted = lastFiatInputString
                    } else {
                        formatted = sendController.convertTokenAmountToCurrency(token: token, amount, false)
                    }
                    converted = sendController.convertAmountToInputString(amount: amount, fractionDigits: token.fractionDigits, symbol: token.symbol)
                } else {
                    formatted = sendController.convertAmountToInputString(amount: amount, fractionDigits: token.fractionDigits)
                    converted = sendController.convertTokenAmountToCurrency(token: token, amount)
                }
            }
        case let .tron(tron):
            switch tron {
            case .usdt:
                if isSwapped {
                    if let lastFiatInputString {
                        formatted = lastFiatInputString
                    } else {
                        formatted = sendController.convertTronUSDTAmountToCurrency(amount, false)
                    }
                    converted = sendController.convertAmountToInputString(amount: amount, fractionDigits: TronSwift.USDT.fractionDigits, symbol: TronSwift.USDT.symbol)
                } else {
                    formatted = sendController.convertAmountToInputString(amount: amount, fractionDigits: TronSwift.USDT.fractionDigits)
                    converted = sendController.convertTronUSDTAmountToCurrency(amount)
                }
            }
        }

        didUpdateCurrency?(isSwapped ? "\(sendController.getCurrency())" : "")
        didUpdateAmount?(formatted)
        self.converted = converted
        updateViewState()
    }

    private func recalculateOnBalanceUpdate() {
        didUpdateItem()
        updateViewState()
    }

    private func updateTokenButton() {
        var name = ""
        var network: String?
        var image: TKImage = .image(nil)

        if case let .withdraw(_, exchangeTo) = sendInput {
            name = exchangeTo.symbol
            network = nil
            if let url = URL(string: exchangeTo.image) {
                image = .urlImage(url)
            }
        } else {
            switch item {
            case let .ton(ton):
                switch ton {
                case let .token(token, _):
                    switch token {
                    case .ton:
                        name = TonInfo.symbol
                        image = .image(.TKCore.Icons.Size44.tonLogo)
                    case let .jetton(item):
                        name = item.jettonInfo.symbol ?? ""
                        image = .urlImage(item.jettonInfo.imageURL)
                    }
                case .nft: break
                }
            case let .tron(tron):
                switch tron {
                case .usdt:
                    name = TronSwift.USDT.symbol
                    image = .image(.App.Currency.Size44.usdt)
                    network = "TRC20"
                }
            }
        }

        didUpdateToken?(
            TokenPickerButton.Configuration(
                name: name,
                network: network,
                image: image
            )
        )
    }

    private func didUpdateItem() {
        let isAmountValid: Bool
        let remaining: SendV3Controller.Remaining
        let formatted: String
        let converted: String

        switch item {
        case let .ton(ton):
            switch ton {
            case .nft:
                isAmountValid = false
                remaining = .insufficient
                formatted = ""
                converted = ""
            case let .token(token, amount):
                isAmountValid = sendController.isAmountAvailableToSend(amount: amount, token: token)
                remaining = sendController.calculateRemaining(token: token, tokenAmount: amount, isSecure: appSettingsStore.getState().isSecureMode)
                if isSwapped {
                    formatted = sendController.convertTokenAmountToCurrency(token: token, amount, false)
                    converted = sendController.convertAmountToInputString(amount: amount, fractionDigits: token.fractionDigits, symbol: token.symbol)
                } else {
                    formatted = sendController.convertAmountToInputString(amount: amount, fractionDigits: token.fractionDigits)
                    converted = sendController.convertTokenAmountToCurrency(token: token, amount)
                }
            }
        case let .tron(tron):
            switch tron {
            case let .usdt(amount):
                isAmountValid = sendController.isTronUSDTAmountAvailableToSend(amount: amount)
                remaining = sendController.calculateTronUSDTRemaining(amount: amount, isSecure: appSettingsStore.getState().isSecureMode)
                if isSwapped {
                    formatted = sendController.convertTronUSDTAmountToCurrency(amount, false)
                    converted = sendController.convertAmountToInputString(amount: amount, fractionDigits: TronSwift.USDT.fractionDigits, symbol: TronSwift.USDT.symbol)
                } else {
                    formatted = sendController.convertAmountToInputString(amount: amount, fractionDigits: TronSwift.USDT.fractionDigits)
                    converted = sendController.convertTronUSDTAmountToCurrency(amount)
                }
            }
        }

        self.isAmountValid = isAmountValid
        self.remaining = remaining
        if case let .withdraw(sourceAsset, exchangeTo) = sendInput {
            self.converted = "1 \(exchangeTo.symbol) = 1 \(sourceAsset.symbol)"
        } else {
            self.converted = converted
        }

        didUpdateAmount?(formatted)
        updateViewState()
        updateTokenButton()
    }

    private func updateViewState() {
        let isTokenPickerEnabled: Bool
        let isSwapVisible: Bool
        if case .withdraw = sendInput {
            isTokenPickerEnabled = false
            isSwapVisible = false
        } else {
            isTokenPickerEnabled = true
            isSwapVisible = true
        }

        let isRecipientValid: Bool
        let isRequiredCommentEmpty: Bool
        let isRecipientNotEmpty: Bool
        var recipientDescription: SendV3ViewModelViewState.RecipientDescription?

        // TODO: Need to simplify all that logic
        if case .withdraw = sendInput {
            let trimmed = recipientInput.trimmingCharacters(in: .whitespacesAndNewlines)
            isRecipientValid = true
            isRecipientNotEmpty = !trimmed.isEmpty
            isRequiredCommentEmpty = false
        } else if let recipient {
            switch item {
            case .ton:
                isRecipientValid = recipient.isTon && !recipient.isScam
                isRequiredCommentEmpty = recipient.isCommentRequired && comment?.isEmpty != false
                if !recipient.isTon {
                    let tronDisabled = configuration.flag(\.tronDisabled, network: wallet.network)
                    let tronBalanceIsZero = balanceStore.getState()[wallet]?.balance.tronUSDT?.amount.isZero ?? true

                    if tronDisabled {
                        recipientDescription = tronBalanceIsZero ? nil : createIncorrectRecipientRecipientDescription(
                            string: TKLocales.Send.IncorrectNetworkRecipient.Trc20.disabled
                        )
                    } else {
                        recipientDescription = createIncorrectRecipientTRC20RecipientDescription()
                    }
                }
            case .tron:
                isRequiredCommentEmpty = false
                isRecipientValid = recipient.isTron
                if !recipient.isTron {
                    recipientDescription = createIncorrectRecipientTonRecipientDescription()
                }
            }
            isRecipientNotEmpty = true

            if recipient.isScam {
                recipientDescription = createIncorrectRecipientRecipientDescription(
                    string: TKLocales.Send.scamAddress
                )
            }

        } else {
            isRecipientValid = recipientInput.isEmpty || recipientResolvingTask != nil
            isRecipientNotEmpty = false
            isRequiredCommentEmpty = false
        }

        if recipientDescription == nil, !isRecipientValid {
            recipientDescription = createIncorrectRecipientRecipientDescription(
                string: TKLocales.Send.invalidAddress
            )
        }

        let limitError = limitErrorForCurrentAmount()

        let balanceState: SendV3ViewModelViewState.BalanceState = {
            let remaining: SendV3ViewModelViewState.BalanceState.Remaining
            switch self.remaining {
            case .insufficient:
                remaining = .insufficient
            case let .remaining(string):
                remaining = .remaining(string)
            }
            return SendV3ViewModelViewState.BalanceState(
                converted: converted,
                remaining: remaining,
                limitError: limitError
            )
        }()

        let continueButtonConfiguration: TKButton.Configuration = {
            let isEnable = {
                let isItemValid = {
                    switch item {
                    case let .ton(item):
                        switch item {
                        case .nft:
                            return true
                        case .token:
                            return isAmountValid
                        }
                    case .tron:
                        return isAmountValid
                    }
                }()

                return !isRequiredCommentEmpty && isRecipientValid && isRecipientNotEmpty && isItemValid && recipientResolvingTask == nil && !isProcessingExchange && limitError == nil
            }()
            var configuration = TKButton.Configuration.actionButtonConfiguration(
                category: .primary,
                size: .large
            )
            configuration.isEnabled = isEnable
            configuration.showsLoader = isProcessingExchange
            configuration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.continueAction))
            configuration.action = { [weak self] in
                self?.continueAction()
            }
            return configuration
        }()

        let commentState: SendV3ViewModelViewState.CommentState? = {
            guard item.isSupportComment else { return nil }

            let isCommentRequired = recipient?.isCommentRequired ?? false
            let comment = self.comment ?? ""
            let isCommentOk = self.sendController.validateComment(comment: comment)

            let isValid: Bool
            let description: NSAttributedString?
            let placeholder: String
            switch (isCommentRequired, comment.isEmpty, isCommentOk) {
            case (_, false, .ledgerNonAsciiError):
                isValid = false
                placeholder = TKLocales.Send.Comment.placeholder
                description = TKLocales.Send.Comment.asciiError.withTextStyle(
                    .body2,
                    color: .Accent.red,
                    alignment: .left,
                    lineBreakMode: .byWordWrapping
                )
            case (false, true, _):
                isValid = true
                placeholder = TKLocales.Send.Comment.placeholder
                description = nil
            case (false, false, _):
                isValid = true
                placeholder = TKLocales.Send.Comment.placeholder
                description = TKLocales.Send.Comment.description.withTextStyle(
                    .body2,
                    color: .Text.secondary,
                    alignment: .left,
                    lineBreakMode: .byWordWrapping
                )
            case (true, true, _):
                isValid = false
                placeholder = TKLocales.Send.RequiredComment.placeholder
                description = TKLocales.Send.RequiredComment.description
                    .withTextStyle(
                        .body2,
                        color: .Accent.orange,
                        alignment: .left,
                        lineBreakMode: .byWordWrapping
                    )
            case (true, false, _):
                isValid = true
                placeholder = TKLocales.Send.RequiredComment.placeholder
                description = TKLocales.Send.RequiredComment.description
                    .withTextStyle(
                        .body2,
                        color: .Accent.orange,
                        alignment: .left,
                        lineBreakMode: .byWordWrapping
                    )
            }

            return SendV3ViewModelViewState.CommentState(
                isValid: isValid,
                placeholder: placeholder,
                description: description
            )
        }()

        let viewState = SendV3ViewModelViewState(
            isRecipientValid: isRecipientValid,
            recipientDescription: recipientDescription,
            balanceState: balanceState,
            continueButtonConfiguration: continueButtonConfiguration,
            commentState: commentState,
            isTokenPickerEnabled: isTokenPickerEnabled,
            isSwapVisible: isSwapVisible
        )

        self.viewState = viewState
    }

    private func continueAction() {
        let isMaxAmount: Bool = {
            switch item {
            case let .ton(ton):
                switch ton {
                case let .token(token, amount):
                    return amount == sendController.getMaximumAmount(token: token)
                default: return false
                }
            case let .tron(tron):
                switch tron {
                case let .usdt(amount):
                    return amount == sendController.getTronUSDTMaximumAmount()
                }
            }
        }()

        if case let .withdraw(sourceAsset, exchangeTo) = sendInput {
            performWithdrawContinue(sourceAsset: sourceAsset, exchangeTo: exchangeTo, isMaxAmount: isMaxAmount)
            return
        }

        guard let data = SendData.sendData(
            wallet: wallet,
            recipient: recipient,
            item: item,
            comment: comment,
            isMaxAmount: isMaxAmount
        ) else { return }
        didContinueSend?(data)
    }

    private func performWithdrawContinue(sourceAsset: OnRampLayoutToken, exchangeTo: OnRampLayoutCryptoMethod, isMaxAmount: Bool) {
        guard !isProcessingExchange else { return }
        let walletAddress = recipientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !walletAddress.isEmpty else { return }

        isProcessingExchange = true
        updateViewState()

        Task { @MainActor in
            defer {
                isProcessingExchange = false
                updateViewState()
            }
            do {
                let result = try await onRampService.createExchange(
                    from: sourceAsset.symbol,
                    to: exchangeTo.symbol,
                    fromNetwork: sourceAsset.network,
                    toNetwork: exchangeTo.network,
                    walletAddress: walletAddress
                )
                let resolvedRecipient = try await sendController.resolveRecipient(input: result.payinAddress)
                guard let data = SendData.sendData(
                    wallet: wallet,
                    recipient: resolvedRecipient,
                    item: item,
                    comment: comment,
                    isMaxAmount: isMaxAmount,
                    recipientDisplayAddress: walletAddress,
                    estimatedDurationSeconds: result.estimatedDuration
                ) else { return }
                didContinueSend?(data)
            } catch {
                // [DEPOSIT] TODO: - fix
                didShowError?(error.localizedDescription)
            }
        }
    }

    private var tronSwapTask: Task<Void, Never>?
    private func createIncorrectRecipientTRC20RecipientDescription() -> SendV3ViewModelViewState.RecipientDescription {
        let string = TKLocales.Send.IncorrectNetworkRecipient.trc20
            .replacingOccurrences(of: "NAME", with: tronSwapTitle)
        return createIncorrectRecipientRecipientDescription(string: string)
    }

    private func createIncorrectRecipientTonRecipientDescription() -> SendV3ViewModelViewState.RecipientDescription {
        let string = TKLocales.Send.IncorrectNetworkRecipient.ton
            .replacingOccurrences(of: "NAME", with: tronSwapTitle)
        return createIncorrectRecipientRecipientDescription(string: string)
    }

    private func createIncorrectRecipientRecipientDescription(string: String) -> SendV3ViewModelViewState.RecipientDescription {
        let result = string.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        ).mutableCopy() as! NSMutableAttributedString

        let tronSwapRange = (string as NSString).range(of: tronSwapTitle)
        result.addAttributes(
            [
                .foregroundColor: UIColor.Accent.blue.cgColor,
            ],
            range: tronSwapRange
        )
        return SendV3ViewModelViewState.RecipientDescription(
            description: result,
            actionItems: [TKActionLabel.ActionItem(
                text: tronSwapTitle,
                action: { [weak self] in
                    self?.tronSwapTask?.cancel()
                    self?.tronSwapTask = Task {
                        guard let self else { return }
                        guard !Task.isCancelled else { return }

                        let tronSwapUrl = self.configuration.value(\.tronSwapUrl)
                        guard let url = URL(string: tronSwapUrl) else { return }

                        await MainActor.run {
                            self.didOpenURL?(url)
                        }
                    }
                }
            )]
        )
    }

    private static func resolveItem(
        from sourceAsset: OnRampLayoutToken,
        wallet: Wallet,
        balanceStore: ConvertedBalanceStore
    ) -> SendV3Item? {
        if sourceAsset.address == TronSwift.USDT.address.base58 {
            return .tron(.usdt(amount: 0))
        }
        if sourceAsset.symbol.uppercased() == TonInfo.symbol.uppercased() {
            return .ton(.token(.ton, amount: 0))
        }

        if sourceAsset.address == JettonMasterAddress.tonUSDT.toRaw() {
            if let balance = balanceStore.state[wallet]?.balance,
               let tonUSDT = balance.jettonsBalance.first(where: { $0.jettonBalance.item.jettonInfo.isTonUSDT })
            {
                return .ton(.token(.jetton(tonUSDT.jettonBalance.item), amount: 0))
            }
            let jettonInfo = JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: JettonMasterAddress.tonUSDT,
                fractionDigits: TronSwift.USDT.fractionDigits,
                name: "Tether USD",
                symbol: TronSwift.USDT.symbol,
                verification: .whitelist,
                imageURL: TronSwift.USDT.imageURL
            )
            let jettonItem = JettonItem(jettonInfo: jettonInfo, walletAddress: nil)
            return .ton(.token(.jetton(jettonItem), amount: 0))
        }

        guard let balance = balanceStore.state[wallet]?.balance else { return nil }

        let jettons = balance.jettonsBalance
        let match = jettons.first { converted in
            converted.jettonBalance.item.jettonInfo.symbol?.lowercased() == sourceAsset.symbol.lowercased()
        }
        if let converted = match {
            return .ton(.token(.jetton(converted.jettonBalance.item), amount: 0))
        }

        return .ton(.token(.ton, amount: 0))
    }

    // MARK: - Withdraw Limits

    private func exchangeLimits(from providers: [OnRampLayoutProvider]) -> (min: Double?, max: Double?) {
        let mins = providers.compactMap { $0.limits?.min }.filter { $0 > 0 }
        let maxs = providers.compactMap { $0.limits?.max }.filter { $0 > 0 }
        return (mins.min(), maxs.max())
    }

    private func limitErrorForCurrentAmount() -> String? {
        guard case let .withdraw(_, exchangeTo) = sendInput else { return nil }
        guard item.amount > 0 else { return nil }
        let limits = exchangeLimits(from: exchangeTo.providers)
        let amountDouble = Double(item.amount) / pow(10, Double(item.fractionalDigits))
        if let min = limits.min, amountDouble < min {
            let formatted = Self.limitsFormatter.string(from: NSNumber(value: min)) ?? "\(min)"
            return TKLocales.Ramp.Withdraw.minAmount(formatted)
        }
        if let max = limits.max, amountDouble > max {
            let formatted = Self.limitsFormatter.string(from: NSNumber(value: max)) ?? "\(max)"
            return TKLocales.Ramp.Withdraw.maxAmount(formatted)
        }
        return nil
    }

    private static let limitsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}

extension SendData {
    static func sendData(
        wallet: Wallet,
        recipient: Recipient?,
        item: SendV3Item,
        comment: String?,
        isMaxAmount: Bool,
        recipientDisplayAddress: String? = nil,
        estimatedDurationSeconds: Int? = nil
    ) -> SendData? {
        guard let recipient else { return nil }
        switch item {
        case let .ton(item):
            guard let recipient = recipient.tonRecipient else { return nil }
            return .ton(
                TonSendData(
                    wallet: wallet,
                    recipient: recipient,
                    item: item,
                    comment: comment,
                    isMaxAmount: isMaxAmount,
                    recipientDisplayAddress: recipientDisplayAddress,
                    estimatedDurationSeconds: estimatedDurationSeconds
                )
            )
        case let .tron(item):
            guard let recipient = recipient.tronRecipient else { return nil }
            return .tron(
                TronSendData(
                    wallet: wallet,
                    recipient: recipient,
                    item: item,
                    recipientDisplayAddress: recipientDisplayAddress,
                    estimatedDurationSeconds: estimatedDurationSeconds
                )
            )
        }
    }
}
