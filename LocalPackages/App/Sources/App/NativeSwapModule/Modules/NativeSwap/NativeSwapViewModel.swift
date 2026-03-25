import BigInt
import Combine
import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import TronSwift

typealias SwapViewEvent = NativeSwapViewModelImplementation.ViewEvent
typealias SwapViewState = NativeSwapViewModelImplementation.ViewState

@MainActor
protocol NativeSwapModuleInput: AnyObject {
    func updateWithToken(_ token: KeeperCore.Token, isSend: Bool)
    func updateFocus(_ isSend: Bool?)
}

@MainActor
protocol NativeSwapModuleOutput: AnyObject {
    var didTapClose: (() -> Void)? { get set }
    var didTapPicker: ((KeeperCore.Token, Bool) -> Void)? { get set }
    var didTapContinue: ((NativeSwapTransactionConfirmationModel) -> Void)? { get set }
}

@MainActor
protocol NativeSwapViewModel: ObservableObject {
    var isSendFocused: Bool { get }

    var didTapClose: (() -> Void)? { get set }
    var didTapPicker: ((KeeperCore.Token, Bool) -> Void)? { get set }
    var didTapContinue: ((NativeSwapTransactionConfirmationModel) -> Void)? { get set }

    var viewEvents: PassthroughSubject<SwapViewEvent, Never> { get }
    var viewState: PassthroughSubject<SwapViewState, Never> { get }
    var amountTextFieldFormatter: SendAmountTextFieldFormatter { get }

    func send(_ event: SwapViewEvent)

    // Public action methods
    func handleMaxTap()
    func handleClearTap()
    func handleSwapTap()
    func handleTokenPickerTap(isSend: Bool)
    func handleContinueTap()
}

// MARK: - NativeSwapViewModelImplementation

@MainActor
final class NativeSwapViewModelImplementation: NativeSwapViewModel, NativeSwapModuleOutput {
    var didTapClose: (() -> Void)?
    var didTapPicker: ((KeeperCore.Token, Bool) -> Void)?
    var didTapContinue: ((NativeSwapTransactionConfirmationModel) -> Void)?

    let viewEvents = PassthroughSubject<SwapViewEvent, Never>()
    let viewState = PassthroughSubject<SwapViewState, Never>()

    let amountTextFieldFormatter: SendAmountTextFieldFormatter = {
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

    private static let decimalNumberHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: 0,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )

    private(set) var isSendFocused = true

    private var subscriptions = Set<AnyCancellable>()

    private let wallet: Wallet
    private let configuration: Configuration
    private let configurationAssembly: ConfigurationAssembly
    private let appSettingsStore: AppSettingsStore
    private let balanceStore: ConvertedBalanceStore
    private let nativeSwapService: NativeSwapService
    private let swapAssetsStore: SwapAssetsStore
    private let currencyStore: CurrencyStore
    private let ratesService: RatesService
    private let sendController: SendV3Controller
    private let amountFormatter: AmountFormatter
    private let analyticsProvider: AnalyticsProvider
    private let resolveJettonInfo: (TonSwift.Address, Network) async throws -> JettonInfo

    /// Helper services
    private let rateFormatter: RateFormatter

    private var model: NativeSwapModel
    private var sendInput = "0"
    private var receiveInput = "0"
    private var confirmation: SwapConfirmation?
    private var currentRequestID = UUID()
    private var initialRateAB: SwapConfirmation?
    private var initialRateBA: SwapConfirmation?

    private var streamTask: Task<Void, Never>?

    struct SwapConfirmationSession {
        var data: SwapConfirmationData
        var requestId: UUID
        var fromToken: KeeperCore.Token
        var toToken: KeeperCore.Token
        var redMetadata: RedAnalyticsMetadata?
    }

    struct ActiveSwapConfirmationSession {
        var request: SwapConfirmationSession
        var redSession: RedAnalyticsSessionHolder
    }

    private let swapConfirmationSubject = PassthroughSubject<SwapConfirmationSession, Never>()
    private var activeQuoteSession: ActiveSwapConfirmationSession?

    deinit {
        streamTask?.cancel()
    }

    init(
        context: AppContext,
        swapDependencies: SwapDependencies,
        fromToken: String? = nil,
        toToken: String? = nil
    ) {
        func findToken(by address: String?) -> KeeperCore.Token {
            guard let address else { return .ton(.ton) }

            if address == TonInfo.symbol.lowercased() {
                return .ton(.ton)
            } else if let jetton = context.balanceStore.state[context.wallet]?.balance.jettonsBalance.first(where: {
                $0.jettonBalance.item.jettonInfo.address.toRaw() == address
            })?.jettonBalance.item {
                return .ton(.jetton(jetton))
            } else if address == TronSwift.USDT.address.base58 {
                return .tron(.usdt)
            }

            return .ton(.ton)
        }

        let fromTokenString = fromToken
        let toTokenString = toToken

        let fromTokenResult = findToken(by: fromTokenString)
        var toTokenResult = findToken(by: toTokenString)

        if fromTokenResult == .ton(.ton), toTokenResult == .ton(.ton) {
            if let jetton = context.balanceStore.state[context.wallet]?.balance.jettonsBalance.first(where: {
                $0.jettonBalance.item.jettonInfo.isTonUSDT
            })?.jettonBalance.item {
                toTokenResult = .ton(.jetton(jetton))
            }
        }

        self.wallet = context.wallet
        self.configuration = context.configuration
        self.configurationAssembly = context.configurationAssembly
        self.model = NativeSwapModel(
            fromToken: fromTokenResult,
            toToken: toTokenResult,
            fromAmount: .init(UIAmount: 0, amount: 0),
            toAmount: .init(UIAmount: 0, amount: 0)
        )
        self.appSettingsStore = context.appSettingsStore
        self.balanceStore = context.balanceStore
        self.nativeSwapService = swapDependencies.nativeSwapService
        self.swapAssetsStore = swapDependencies.swapAssetsStore
        self.currencyStore = context.currencyStore
        self.ratesService = swapDependencies.ratesService
        self.sendController = swapDependencies.sendController
        self.amountFormatter = context.amountFormatter
        self.analyticsProvider = context.analyticsProvider
        self.resolveJettonInfo = swapDependencies.resolveJettonInfo

        // Initialize helper services
        self.rateFormatter = RateFormatter(amountFormatter: amountFormatter)

        amountTextFieldFormatter.maximumFractionDigits = model.fromToken.fractionDigits

        setupBinding()
    }

    func send(_ event: ViewEvent) {
        viewEvents.send(event)
    }

    // MARK: - Public Action Methods

    func handleMaxTap() {
        updateMaxAmount()
    }

    func handleClearTap() {
        clearAmountInputs()
    }

    func handleSwapTap() {
        swapTokens()
    }

    func handleTokenPickerTap(isSend: Bool) {
        didTapPicker?(isSend ? model.fromToken : model.toToken, isSend)
    }

    func handleContinueTap() {
        guard let confirmation else { return }

        let sendSymbol = model.fromToken.name
        let sendFormatted = "\(sendInput) \(sendSymbol)"

        let receiveSymbol = model.toToken.name
        let receiveFormatted = "\(TKLocales.Common.Numbers.approximate) \(receiveInput) \(receiveSymbol)"

        analyticsProvider.log(event: .NativeSwap.click(
            from: model.fromToken.analyticsSymbol,
            to: model.toToken.analyticsSymbol
        ))

        didTapContinue?(
            NativeSwapTransactionConfirmationModel(
                fromToken: model.fromToken,
                toToken: model.toToken,
                fromAmount: model.fromAmount.amount,
                toAmount: model.toAmount.amount,
                sendFormatted: sendFormatted,
                receiveFormatted: receiveFormatted,
                rateFormatted: rateFormatter.formatExchangeRateForOneToken(
                    confirmation: confirmation,
                    fromToken: model.fromToken,
                    toToken: model.toToken
                ),
                confirmation: confirmation
            )
        )
    }

    private func setupBinding() {
        viewEvents
            .sink { [weak self] event in
                guard let self else { return }

                switch event {
                case .didViewLoad:
                    didViewLoad()
                case .didViewAppear:
                    viewDidAppear()
                case .didViewDisappear:
                    cancelPendingSwapRequests()
                case let .didUpdateAmount(text, isSend):
                    updateAmount(text, isSend: isSend)
                }
            }
            .store(in: &subscriptions)

        swapConfirmationSubject
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self else { return }

                // Validate request is still current before starting stream
                guard session.requestId == currentRequestID else { return }

                streamTask?.cancel()
                let redSession = RedAnalyticsSessionHolder(
                    analytics: analyticsProvider,
                    configurationAssembly: configurationAssembly
                )
                redSession.start(
                    flow: .swap,
                    operation: .quote,
                    attemptSource: .nativeUI,
                    otherMetadata: session.redMetadata
                )
                let activeSession = ActiveSwapConfirmationSession(
                    request: session,
                    redSession: redSession
                )
                activeQuoteSession = activeSession
                streamTask = Task { [weak self] in
                    await MainActor.run {
                        self?.updateViewState(.process)
                    }

                    await self?.subscribeToSwapStream(session: activeSession)
                }
            }
            .store(in: &subscriptions)
    }

    private func didViewLoad() {
        updateViewState(.success)
        fetchAssets()
        requestInitialRates()
        analyticsProvider.log(event: .NativeSwap.open())
    }

    private func requestInitialRates() {
        guard let userAddress = try? wallet.address.toRaw() else { return }

        self.initialRateAB = nil
        self.initialRateBA = nil
        self.updateViewState(.process)

        // Request rate A->B (1 unit of fromToken)
        let oneUnitAB = BigUInt(1).multiplied(by: BigUInt(10).power(model.fromToken.fractionDigits))
        let dataAB = SwapConfirmationData(
            fromAsset: model.fromToken.chartIdentifier.lowercased(),
            toAsset: model.toToken.chartIdentifier.lowercased(),
            fromAmount: oneUnitAB.description,
            toAmount: "0",
            userAddress: userAddress,
            isSend: true
        )

        // Request rate B->A (1 unit of toToken)
        let oneUnitBA = BigUInt(1).multiplied(by: BigUInt(10).power(model.toToken.fractionDigits))
        let dataBA = SwapConfirmationData(
            fromAsset: model.toToken.chartIdentifier.lowercased(),
            toAsset: model.fromToken.chartIdentifier.lowercased(),
            fromAmount: oneUnitBA.description,
            toAmount: "0",
            userAddress: userAddress,
            isSend: true
        )

        Task { [weak self] in
            guard let self else { return }

            async let rateABTask: Void = {
                do {
                    for await confirmationResult in await self.nativeSwapService
                        .subscribeToSwapConfirmation(data: dataAB, network: self.wallet.network)
                    {
                        guard !Task.isCancelled else { return }

                        let confirmation = try confirmationResult.get()

                        await MainActor.run {
                            self.initialRateAB = confirmation
                            self.updateViewState(.success)
                        }
                        break
                    }
                } catch {
                    // Silently fail - initial rate is optional
                }
            }()

            async let rateBATask: Void = {
                do {
                    for await confirmationResult in await self.nativeSwapService
                        .subscribeToSwapConfirmation(data: dataBA, network: self.wallet.network)
                    {
                        guard !Task.isCancelled else { return }

                        let confirmation = try confirmationResult.get()

                        await MainActor.run {
                            self.initialRateBA = confirmation
                            self.updateViewState(.success)
                        }
                        break
                    }
                } catch {
                    // Silently fail - initial rate is optional
                }
            }()

            await rateABTask
            await rateBATask

            if self.initialRateAB == nil && self.initialRateBA == nil {
                // to update UI from .process state
                self.updateViewState(.success)
            }
        }
    }

    private func viewDidAppear() {
        guard model.fromAmount.amount > 0 else { return }

        updateAmount(sendInput, isSend: true)
    }

    private func updateAmount(_ text: String, isSend: Bool) {
        isSendFocused = isSend

        let unformatted = amountTextFieldFormatter.unformatString(text) ?? ""

        if isSendFocused {
            updateSendAmount(text: text, unformatted: unformatted)
        } else {
            updateReceiveAmount(text: text, unformatted: unformatted)
        }
    }

    private func updateSendAmount(text: String, unformatted: String) {
        amountTextFieldFormatter.maximumFractionDigits = model.fromToken.fractionDigits

        let fromAmount = sendController.tokenAmountFromTokenInput(
            tokenInput: unformatted,
            fractionDigits: amountTextFieldFormatter.maximumFractionDigits
        )

        sendInput = text
        model.fromAmount.UIAmount = fromAmount

        guard !text.isEmpty, fromAmount > 0 else {
            cancelPendingSwapRequests()
            model.toAmount.UIAmount = 0
            receiveInput = "0"
            updateViewState(.success)
            return
        }

        updateReceiveEstimateFromSend(fromAmount: fromAmount)
        updateStreamConfirmation()
    }

    private func updateReceiveAmount(text: String, unformatted: String) {
        amountTextFieldFormatter.maximumFractionDigits = model.toToken.fractionDigits

        let toAmount = sendController.tokenAmountFromTokenInput(
            tokenInput: unformatted,
            fractionDigits: amountTextFieldFormatter.maximumFractionDigits
        )

        receiveInput = text
        model.toAmount.UIAmount = toAmount

        guard !text.isEmpty, toAmount > 0 else {
            cancelPendingSwapRequests()
            model.fromAmount.UIAmount = 0
            sendInput = "0"
            updateViewState(.success)
            return
        }

        updateSendEstimateFromReceive(toAmount: toAmount)
        updateStreamConfirmation()
    }

    private func updateMaxAmount() {
        switch model.fromToken {
        case let .ton(token):
            let amount = sendController.getMaximumAmount(token: token)
            updateMaxAmountWithExactValue(amount)
        case .tron:
            let amount = sendController.getTronUSDTMaximumAmount()
            updateMaxAmountWithExactValue(amount)
        }
    }

    private func updateMaxAmountWithExactValue(_ amount: BigUInt) {
        isSendFocused = true

        sendInput = amountFormatter.format(
            amount: amount,
            fractionDigits: model.fromToken.fractionDigits,
            style: .exactValue
        )
        model.fromAmount.UIAmount = amount

        guard amount > 0 else {
            cancelPendingSwapRequests()
            model.toAmount.UIAmount = 0
            receiveInput = ""
            updateViewState(.success)
            return
        }

        updateReceiveEstimateFromSend(fromAmount: amount)
        updateStreamConfirmation()
    }

    private func clearAmountInputs() {
        cancelPendingSwapRequests()

        sendInput = ""
        receiveInput = ""

        model.fromAmount.UIAmount = 0
        model.toAmount.UIAmount = 0

        updateViewState(.success)
    }

    private func updateViewState(_ state: ViewState.State) {
        let isSendShimmering = state == .process && !isSendFocused
        let isReceiveShimmering = state == .process && isSendFocused

        let state = ViewState(
            state: state,
            sendAmount: sendInput,
            receiveAmount: receiveInput,
            rateAB: rateFormatter.formatExchangeRateAB(
                initialRate: initialRateAB,
                fromToken: model.fromToken,
                toToken: model.toToken
            ),
            rateBA: rateFormatter.formatExchangeRateBA(
                initialRate: initialRateBA,
                fromToken: model.fromToken,
                toToken: model.toToken
            ),
            remaining: getRemaining(),
            sendTokenConfiguration: getTokenButton(token: model.fromToken),
            receiveTokenConfiguration: getTokenButton(token: model.toToken),
            isContinueButtonEnabled: getContinueButtonEnableState(),
            isSendFocused: isSendFocused,
            isSendShimmering: isSendShimmering,
            isReceiveShimmering: isReceiveShimmering
        )

        viewState.send(state)
    }

    private func swapTokens() {
        // Cancel any pending debounced requests and active stream
        cancelPendingSwapRequests()

        model = model.swap()

        // Swap the initial rates as well
        let tempRate = initialRateAB
        initialRateAB = initialRateBA
        initialRateBA = tempRate

        if isSendFocused {
            let tempInput = receiveInput
            self.receiveInput = sendInput
            self.sendInput = tempInput
        } else {
            let tempInput = sendInput
            self.sendInput = receiveInput
            self.receiveInput = tempInput
        }

        guard model.fromAmount.amount > 0 else {
            updateViewState(.success)
            return
        }

        let shouldFocusSend = !isSendFocused
        updateAmount(shouldFocusSend ? sendInput : receiveInput, isSend: shouldFocusSend)
    }

    private func getTokenButton(token: KeeperCore.Token?) -> TokenPickerButton.Configuration {
        var name = ""
        var network: String?
        var image = TKImage.image(nil)

        guard let token else {
            return TokenPickerButton.Configuration(
                name: name,
                network: network,
                image: image
            )
        }

        switch token {
        case let .ton(token):
            switch token {
            case let .jetton(item):
                name = item.jettonInfo.symbol ?? ""
                image = .urlImage(item.jettonInfo.imageURL)
            case .ton:
                name = TonInfo.symbol
                image = .image(.TKCore.Icons.Size44.tonLogo)
            }
        case .tron:
            name = TronSwift.USDT.symbol
            image = .image(.App.Currency.Size44.usdt)
            network = "TRC20"
        }

        return TokenPickerButton.Configuration(
            name: name,
            network: network,
            image: image
        )
    }

    private func updateReceiveEstimateFromSend(fromAmount: BigUInt) {
        // Don't calculate estimate for zero amount
        guard fromAmount > 0 else { return }

        // Show estimate based on initial rate while waiting for real rate
        guard let initialRate = initialRateAB else { return }

        let estimatedToAmount = calculateEstimatedAmount(
            inputAmount: fromAmount,
            fromDecimals: model.fromToken.fractionDigits,
            toDecimals: model.toToken.fractionDigits,
            rate: initialRate
        )
        model.toAmount.amount = estimatedToAmount
        receiveInput = amountFormatter.format(
            amount: estimatedToAmount,
            fractionDigits: model.toToken.fractionDigits
        )
    }

    private func updateSendEstimateFromReceive(toAmount: BigUInt) {
        // Don't calculate estimate for zero amount
        guard toAmount > 0 else { return }

        // Show estimate based on initial rate while waiting for real rate
        guard let initialRate = initialRateBA else { return }

        let estimatedFromAmount = calculateEstimatedAmount(
            inputAmount: toAmount,
            fromDecimals: model.toToken.fractionDigits,
            toDecimals: model.fromToken.fractionDigits,
            rate: initialRate
        )
        model.fromAmount.amount = estimatedFromAmount
        sendInput = amountFormatter.format(
            amount: estimatedFromAmount,
            fractionDigits: model.fromToken.fractionDigits
        )
    }

    private func calculateEstimatedAmount(
        inputAmount: BigUInt,
        fromDecimals: Int,
        toDecimals: Int,
        rate: SwapConfirmation
    ) -> BigUInt {
        let rateBidUnits = BigUInt(rate.bidUnits) ?? 0
        let rateAskUnits = BigUInt(rate.askUnits) ?? 0

        guard rateBidUnits > 0, rateAskUnits > 0 else { return 0 }

        // The rate response gives us: rateBidUnits (input) -> rateAskUnits (output)
        // Both are in raw units (already multiplied by their respective decimals)
        // Formula: outputAmount = (inputAmount * rateAskUnits) / rateBidUnits

        let inputDecimal = NSDecimalNumber(string: inputAmount.description)
        let bidDecimal = NSDecimalNumber(string: rateBidUnits.description)
        let askDecimal = NSDecimalNumber(string: rateAskUnits.description)

        // Calculate: (inputAmount * rateAskUnits) / rateBidUnits
        let numerator = inputDecimal.multiplying(by: askDecimal)
        let result = numerator.dividing(by: bidDecimal)
        let rounded = result.rounding(accordingToBehavior: Self.decimalNumberHandler)

        return BigUInt(rounded.stringValue) ?? 0
    }

    private func getRemaining() -> ViewState.Remaining {
        let isSecure = appSettingsStore.getState().isSecureMode

        let type = switch model.fromToken {
        case let .ton(token):
            sendController.calculateRemaining(
                token: token,
                tokenAmount: model.fromAmount.UIAmount,
                isSecure: isSecure
            )
        case .tron:
            sendController.calculateTronUSDTRemaining(
                amount: model.fromAmount.UIAmount,
                isSecure: isSecure
            )
        }

        return switch type {
        case .insufficient:
            .insufficient
        case let .remaining(text):
            model.fromAmount.UIAmount.isZero
                ? .remaining(TKLocales.NativeSwap.balance(text))
                : .remaining(TKLocales.NativeSwap.remaining(text))
        }
    }

    private func getContinueButtonEnableState() -> Bool {
        let isAmountValid = switch model.fromToken {
        case let .ton(token):
            sendController.isAmountAvailableToSend(amount: model.fromAmount.amount, token: token)
        case .tron:
            sendController.isTronUSDTAmountAvailableToSend(amount: model.fromAmount.amount)
        }
        return isAmountValid && model.fromAmount.amount > 0 && confirmation != nil
    }

    private func fetchAssets() {
        Task { @MainActor in
            let assets = try? await nativeSwapService.fetchAssets(network: wallet.network)
            await swapAssetsStore.setAssets(assets ?? [])
        }
    }

    private func cancelPendingSwapRequests() {
        activeQuoteSession?.redSession.finish(
            outcome: .cancel,
            stage: "quote"
        )
        activeQuoteSession = nil

        // Generate new request ID to invalidate any in-flight responses
        currentRequestID = UUID()

        // Cancel active stream task
        streamTask?.cancel()
        streamTask = nil

        // Clear confirmation data
        confirmation = nil
    }

    private func updateStreamConfirmation() {
        guard let userAddress = try? wallet.address.toRaw() else { return }

        // Cancel any pending requests before starting new one
        cancelPendingSwapRequests()

        let data = SwapConfirmationData(
            fromAsset: model.fromToken.chartIdentifier.lowercased(),
            toAsset: model.toToken.chartIdentifier.lowercased(),
            fromAmount: model.fromAmount.amount.description,
            toAmount: model.toAmount.amount.description,
            userAddress: userAddress,
            isSend: isSendFocused
        )
        swapConfirmationSubject.send(
            SwapConfirmationSession(
                data: data,
                requestId: currentRequestID,
                fromToken: model.fromToken,
                toToken: model.toToken,
                redMetadata: quoteRedMetadata(data: data)
            )
        )
    }

    private func subscribeToSwapStream(
        session: ActiveSwapConfirmationSession
    ) async {
        do {
            for await confirmationResult in nativeSwapService.subscribeToSwapConfirmation(data: session.request.data, network: wallet.network) {
                guard !Task.isCancelled else { return }
                let confirmation = try confirmationResult.get()

                // Validate response matches current request and token pair
                await handleSwapEvent(confirmation, session: session)
            }
        } catch {
            guard !Task.isCancelled else { return }
            session.redSession.finish(
                outcome: .fail,
                error: error,
                stage: "quote"
            )
            clearActiveQuoteSession(requestId: session.request.requestId)
            updateViewState(.failed)

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }

            updateViewState(.success)
        }
    }

    @MainActor
    private func handleSwapEvent(
        _ confirmation: SwapConfirmation,
        session: ActiveSwapConfirmationSession
    ) async {
        // Ignore stale responses from old token pairs or cancelled requests
        guard
            session.request.requestId == currentRequestID,
            model.fromToken == session.request.fromToken,
            model.toToken == session.request.toToken
        else {
            return
        }

        session.redSession.finish(
            outcome: .success,
            stage: "quote"
        )
        clearActiveQuoteSession(requestId: session.request.requestId)
        self.confirmation = confirmation

        if isSendFocused {
            model.toAmount.amount = BigUInt(confirmation.askUnits) ?? 0
            receiveInput = sendInput.isEmpty ? "" : amountFormatter.format(
                amount: model.toAmount.UIAmount,
                fractionDigits: model.toToken.fractionDigits
            )
        } else {
            model.fromAmount.amount = BigUInt(confirmation.bidUnits) ?? 0
            sendInput = receiveInput.isEmpty ? "" : amountFormatter.format(
                amount: model.fromAmount.UIAmount,
                fractionDigits: model.fromToken.fractionDigits
            )
        }

        updateViewState(.success)
    }

    private func quoteRedMetadata(data: SwapConfirmationData) -> RedAnalyticsMetadata? {
        [
            "from_asset": data.fromAsset,
            "to_asset": data.toAsset,
            "from_amount": data.fromAmount,
            "to_amount": data.toAmount,
            "is_send": data.isSend,
        ]
    }

    private func clearActiveQuoteSession(requestId: UUID) {
        guard activeQuoteSession?.request.requestId == requestId else { return }
        activeQuoteSession = nil
    }
}

// MARK: - Rate Formatting

extension NativeSwapViewModelImplementation {
    final class RateFormatter {
        private let amountFormatter: AmountFormatter
        private static let decimalNumberHandler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )

        init(amountFormatter: AmountFormatter) {
            self.amountFormatter = amountFormatter
        }

        func formatExchangeRateAB(
            initialRate: SwapConfirmation?,
            fromToken: KeeperCore.Token,
            toToken: KeeperCore.Token
        ) -> String {
            guard let rateConfirmation = initialRate else { return "" }

            let fromAmount = BigUInt(rateConfirmation.bidUnits) ?? 0
            let toAmount = BigUInt(rateConfirmation.askUnits) ?? 0

            guard fromAmount > 0, toAmount > 0 else { return "" }

            let fromSymbol = fromToken.symbol
            let toSymbol = getToTokenSymbol(token: toToken)

            let fromDecimalNumber = NSDecimalNumber.fromBigUInt(
                value: fromAmount,
                decimals: fromToken.fractionDigits
            )
            let toDecimalNumber = NSDecimalNumber.fromBigUInt(
                value: toAmount,
                decimals: toToken.fractionDigits
            )

            let rateDecimal = toDecimalNumber.dividing(by: fromDecimalNumber)
            let rateMultiplied = rateDecimal.multiplying(byPowerOf10: Int16(toToken.fractionDigits))
            let roundedRate = rateMultiplied.rounding(accordingToBehavior: Self.decimalNumberHandler)

            let formattedRate = amountFormatter.format(
                amount: BigUInt(roundedRate.stringValue) ?? 0,
                fractionDigits: toToken.fractionDigits
            )

            return "1 \(fromSymbol) \(TKLocales.Common.Numbers.approximate) \(formattedRate) \(toSymbol)"
        }

        func formatExchangeRateBA(
            initialRate: SwapConfirmation?,
            fromToken: KeeperCore.Token,
            toToken: KeeperCore.Token
        ) -> String {
            guard let rateConfirmation = initialRate else { return "" }

            let fromAmount = BigUInt(rateConfirmation.bidUnits) ?? 0
            let toAmount = BigUInt(rateConfirmation.askUnits) ?? 0

            guard fromAmount > 0, toAmount > 0 else { return "" }

            let fromSymbol = getToTokenSymbol(token: toToken)
            let toSymbol = fromToken.symbol

            let fromDecimalNumber = NSDecimalNumber.fromBigUInt(
                value: fromAmount,
                decimals: toToken.fractionDigits
            )
            let toDecimalNumber = NSDecimalNumber.fromBigUInt(
                value: toAmount,
                decimals: fromToken.fractionDigits
            )

            let rateDecimal = toDecimalNumber.dividing(by: fromDecimalNumber)
            let rateMultiplied = rateDecimal.multiplying(byPowerOf10: Int16(fromToken.fractionDigits))
            let roundedRate = rateMultiplied.rounding(accordingToBehavior: Self.decimalNumberHandler)

            let formattedRate = amountFormatter.format(
                amount: BigUInt(roundedRate.stringValue) ?? 0,
                fractionDigits: fromToken.fractionDigits
            )

            return "1 \(fromSymbol) \(TKLocales.Common.Numbers.approximate) \(formattedRate) \(toSymbol)"
        }

        func formatExchangeRateForOneToken(
            confirmation: SwapConfirmation?,
            fromToken: KeeperCore.Token,
            toToken: KeeperCore.Token
        ) -> String {
            guard let confirmation else { return "" }

            let fromAmount = BigUInt(confirmation.bidUnits) ?? 0
            let toAmount = BigUInt(confirmation.askUnits) ?? 0

            guard fromAmount > 0, toAmount > 0 else { return "" }

            let fromSymbol = fromToken.symbol
            let toSymbol = getToTokenSymbol(token: toToken)

            let fromDecimalNumber = NSDecimalNumber.fromBigUInt(
                value: fromAmount,
                decimals: fromToken.fractionDigits
            )
            let toDecimalNumber = NSDecimalNumber.fromBigUInt(
                value: toAmount,
                decimals: toToken.fractionDigits
            )

            let rateDecimal = toDecimalNumber.dividing(by: fromDecimalNumber)
            let rateMultiplied = rateDecimal.multiplying(byPowerOf10: Int16(toToken.fractionDigits))
            let roundedRate = rateMultiplied.rounding(accordingToBehavior: Self.decimalNumberHandler)

            let formattedRate = amountFormatter.format(
                amount: BigUInt(roundedRate.stringValue) ?? 0,
                fractionDigits: toToken.fractionDigits
            )

            return "1 \(fromSymbol) \(TKLocales.Common.Numbers.approximate) \(formattedRate) \(toSymbol)"
        }

        func getToTokenSymbol(token: KeeperCore.Token) -> String {
            switch token {
            case let .ton(token): token.symbol
            case .tron: token.symbol + " TRC20"
            }
        }
    }
}

// MARK: - Module Input

extension NativeSwapViewModelImplementation: NativeSwapModuleInput {
    func updateWithToken(_ token: KeeperCore.Token, isSend: Bool) {
        // Cancel pending requests when token changes
        cancelPendingSwapRequests()

        func proceed(with updatedToken: KeeperCore.Token) {
            if model.fromToken == updatedToken || model.toToken == updatedToken {
                swapTokens()
                return
            }

            if isSend {
                model.fromToken = updatedToken
                updateAmount(sendInput, isSend: true)
            } else {
                model.toToken = updatedToken
                updateAmount(sendInput, isSend: true)
            }

            // Re-request initial rates with new token pair
            requestInitialRates()
        }

        switch token {
        case let .ton(tonToken):
            switch tonToken {
            case .ton:
                proceed(with: token)
            case let .jetton(jettonItem):
                Task {
                    do {
                        let resolvedJettonInfo = try await resolveJettonInfo(jettonItem.jettonInfo.address, wallet.network)
                        let jetton = JettonItem(jettonInfo: resolvedJettonInfo, walletAddress: jettonItem.walletAddress)
                        await MainActor.run {
                            proceed(with: .ton(.jetton(jetton)))
                        }
                    } catch {
                        Log.w("\(error)")
                        await MainActor.run {
                            proceed(with: token)
                        }
                    }
                }
            }
        case .tron:
            proceed(with: token)
        }
    }

    func updateFocus(_ isSend: Bool?) {
        guard let isSend else { return }

        isSendFocused = isSend
        updateViewState(.success)
    }
}

// MARK: - ViewEvent & ViewState

extension NativeSwapViewModelImplementation {
    enum ViewEvent {
        case didViewLoad
        case didViewAppear
        case didViewDisappear
        case didUpdateAmount(String, Bool)
    }

    struct ViewState {
        let state: ViewState.State
        let sendAmount: String
        let receiveAmount: String
        let rateAB: String
        let rateBA: String
        let remaining: ViewState.Remaining
        let sendTokenConfiguration: TokenPickerButton.Configuration
        let receiveTokenConfiguration: TokenPickerButton.Configuration
        let isContinueButtonEnabled: Bool
        let isSendFocused: Bool
        let isSendShimmering: Bool
        let isReceiveShimmering: Bool

        enum Remaining {
            case insufficient
            case remaining(String)
        }

        enum State {
            case process
            case success
            case failed
        }
    }
}
