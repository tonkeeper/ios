import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLogging
import TKUIKit

@MainActor
final class MultichainSwapViewModel: ObservableObject {
    let amountFormatter: AmountFormatter
    let isAssetSelectionLocked: Bool

    private static let routeExpiryMargin: TimeInterval = 5
    private static let sendFailureNanoseconds: UInt64 = 4_000_000_000
    private static let minimumRefreshDuration: TimeInterval = 5

    private let quoteRefreshDuration: TimeInterval
    private let sendFailureWait: MultichainSwapQuotePairViewModel.Wait
    let now: () -> Date
    private let swapWallet: MultichainSwapWallet
    /// The `/v3` switch as the coordinator read it when it built the screen: every pair here is quoted
    /// on `/v3` only if it was on.
    private let isSwapV3Enabled: Bool
    private let defaultAssetsService: MultichainSwapDefaultAssetsService
    private var raffleObserver: MysteryRafflePresentationObserver?
    private var shownRaffleBannerIDs = Set<String>()
    private let analyticsProvider: AnalyticsProvider?
    private let swapAnalytics: MultichainSwapAnalytics?
    private let onClose: () -> Void
    private let onOpenConfirmation: (
        MultichainSwapConfirmationInput,
        MultichainSwapQuoteRefreshCycle,
        MultichainSwapConfirmationPhase
    ) -> Void
    private let onInitialSelectionUnavailable: () -> Void
    private let onQuoteProviderError: (String) -> Void
    private let onQuoteOffline: () -> Void
    private let onTonMaxAmountUnavailable: () -> Void
    private let onOpenRaffle: () -> Void
    private let onOpenPriceImpactInfo: () -> Void
    private let onRefillBattery: (_ onRecharged: @escaping () -> Void) -> Void

    let quoteViewModel: MultichainSwapQuoteViewModel
    private let calculator: MultichainSwapAmountCalculator
    private let stateMaker: MultichainSwapStateMaker
    private let planProvider: MultichainSwapPlanProvider?
    private let batteryPromo: MultichainSwapBatteryPromo?

    @Published private(set) var state: MultichainSwapViewModelState = .shimmer
    @Published private(set) var rafflePresentation: MysteryRafflePresentation?
    @Published private(set) var focusRequestID: Int = 0
    /// Set while the confirmation runs over this screen. It shows this screen's quote and countdown and
    /// asks for no quotes on a timer of its own.
    @Published private(set) var confirmationPhase: MultichainSwapConfirmationPhase?
    @Published private(set) var sendFailure: MultichainSwapSendFailure?
    /// The API of the route the confirmation opened with: every quote it is shown, after its countdown or
    /// a new slippage, comes from there, however the flag moves meanwhile.
    private var confirmationAPIVersion: MultichainSwapAPIVersion?

    private var inputs: MultichainSwapInputs?
    private var quoteSnapshot: MultichainSwapQuoteSnapshot = .initial() {
        didSet {
            guard quoteSnapshot.progressStartDate != oldValue.progressStartDate else {
                return
            }
            scheduleQuoteCountdown()
        }
    }

    private var initialAssetsTask: Task<Void, Never>?
    private var quoteCountdownTimer: Timer?
    private var sendFailureTask: Task<Void, Never>?
    /// The plan of the route the fee row was last asked about.
    private var feePlan: (routeId: String, plan: MultichainSwapFeePlan)?
    private var feePlanTask: Task<Void, Never>?
    /// The send assets the battery promo stands for, once it turned out to be offered this time.
    private var batteryPromoCoverage: ((MultichainAsset) -> Bool)?
    private var isBatteryPromoShown = false
    private var batteryPromoTask: Task<Void, Never>?

    var onRequestPickSendToken: (() -> Void)?
    var onRequestPickReceiveToken: (() -> Void)?
    var onConfirmationQuoteChange: ((MultichainSwapConfirmationQuoteUpdate) -> Void)?

    init(
        amountFormatter: AmountFormatter,
        multichainSwapService: MultichainSwapService,
        swapWallet: MultichainSwapWallet,
        defaultAssetsService: MultichainSwapDefaultAssetsService,
        isAssetSelectionLocked: Bool = false,
        displayCurrency: Currency = .defaultCurrency,
        isSwapKitEnabled: Bool = false,
        isExactOutputEnabled: Bool = false,
        isSwapV3Enabled: Bool = false,
        raffleStore: RaffleStore? = nil,
        analyticsProvider: AnalyticsProvider? = nil,
        swapAnalytics: MultichainSwapAnalytics? = nil,
        planProvider: MultichainSwapPlanProvider? = nil,
        batteryPromo: MultichainSwapBatteryPromo? = nil,
        onClose: @escaping () -> Void = {},
        onOpenConfirmation: @escaping (
            MultichainSwapConfirmationInput,
            MultichainSwapQuoteRefreshCycle,
            MultichainSwapConfirmationPhase
        ) -> Void = { _, _, _ in },
        onInitialSelectionUnavailable: @escaping () -> Void = {},
        onQuoteProviderError: @escaping (String) -> Void = { _ in },
        onQuoteOffline: @escaping () -> Void = {},
        onTonMaxAmountUnavailable: @escaping () -> Void = {},
        onOpenRaffle: @escaping () -> Void = {},
        onOpenPriceImpactInfo: @escaping () -> Void = {},
        onRefillBattery: @escaping (_ onRecharged: @escaping () -> Void) -> Void = { _ in },
        quoteRefreshDuration: TimeInterval = 60,
        sendFailureWait: MultichainSwapQuotePairViewModel.Wait? = nil,
        quoteDebounce: MultichainSwapQuotePairViewModel.Wait? = nil,
        routeExpiryWait: MultichainSwapQuotePairViewModel.Wait? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.amountFormatter = amountFormatter
        self.now = now
        self.planProvider = planProvider
        self.batteryPromo = batteryPromo
        self.quoteRefreshDuration = quoteRefreshDuration
        self.sendFailureWait = sendFailureWait ?? { try await Task.sleep(nanoseconds: $0) }
        self.swapWallet = swapWallet
        self.isSwapV3Enabled = isSwapV3Enabled
        self.defaultAssetsService = defaultAssetsService
        self.isAssetSelectionLocked = isAssetSelectionLocked
        self.analyticsProvider = analyticsProvider
        self.swapAnalytics = swapAnalytics
        self.onClose = onClose
        self.onOpenConfirmation = onOpenConfirmation
        self.onInitialSelectionUnavailable = onInitialSelectionUnavailable
        self.onQuoteProviderError = onQuoteProviderError
        self.onQuoteOffline = onQuoteOffline
        self.onTonMaxAmountUnavailable = onTonMaxAmountUnavailable
        self.onOpenRaffle = onOpenRaffle
        self.onOpenPriceImpactInfo = onOpenPriceImpactInfo
        self.onRefillBattery = onRefillBattery

        let calculator = MultichainSwapAmountCalculator(
            amountFormatter: amountFormatter,
            displayCurrency: displayCurrency
        )
        self.calculator = calculator
        self.stateMaker = MultichainSwapStateMaker(
            calculator: calculator,
            validator: MultichainSwapValidator(
                calculator: calculator,
                swapWallet: swapWallet
            ),
            exactOutputSupport: MultichainSwapExactOutputSupport(isEnabled: isExactOutputEnabled)
        )
        self.quoteViewModel = MultichainSwapQuoteViewModel(
            multichainSwapService: multichainSwapService,
            requestedAggregators: MultichainSwapQuoteRequest.requestedAggregators(
                isSwapKitEnabled: isSwapKitEnabled
            ),
            debounce: quoteDebounce,
            routeExpiryWait: routeExpiryWait,
            now: now
        )
        self.quoteViewModel.onSnapshotChange = { [weak self] snapshot in
            self?.applyQuoteSnapshot(snapshot)
        }
        self.quoteViewModel.onProviderErrorMessage = { [weak self] message in
            self?.onQuoteProviderError(message)
        }
        raffleObserver = MysteryRafflePresentationObserver(
            raffleStore: raffleStore
        ) { [weak self] raffles in
            self?.rafflePresentation = MysteryRafflePresentation(raffles: raffles)
            self?.logRaffleBannerViewIfNeeded()
        }
        loadInitialAssets()
        loadBatteryPromo()
    }

    deinit {
        initialAssetsTask?.cancel()
        sendFailureTask?.cancel()
        feePlanTask?.cancel()
        batteryPromoTask?.cancel()
    }

    func requestFocusOnAppear() {
        focusRequestID += 1
    }

    func close() {
        initialAssetsTask?.cancel()
        onClose()
    }

    func retryLoading() {
        loadInitialAssets()
    }

    func openRaffle() {
        analyticsProvider?.log(RaffleBannerClick(source: .swapPromo))
        onOpenRaffle()
    }

    /// Fires `raffle_banner_view` once per raffle id while the swap promo is eligible.
    /// The observer re-derives on a timer, so dedup on id.
    private func logRaffleBannerViewIfNeeded() {
        guard let presentation = rafflePresentation, presentation.shouldShowSwapPromo else { return }
        guard shownRaffleBannerIDs.insert(presentation.raffle.id).inserted else { return }
        analyticsProvider?.log(RaffleBannerView(source: .swapPromo))
    }

    /// A known fee goes straight to the passcode. An unknown fee is estimated again in the pricing
    /// details, where the user sees it before the swap goes.
    func continueSwap() {
        guard case let .loaded(loadedState) = state else {
            return
        }
        let phase: MultichainSwapConfirmationPhase = loadedState.feeSummary == .unknown ? .pricingDetails : .swapping
        guard let input = openConfirmation(phase) else {
            return
        }
        // The pricing details send it from their own Swap button, the one that starts the swap there.
        if phase == .swapping {
            swapAnalytics?.logClick(input)
        }
    }

    func openPricingDetails() {
        openConfirmation(.pricingDetails)
    }

    func openPriceImpactInfo() {
        onOpenPriceImpactInfo()
    }

    /// The battery is all that could pay and it is short. The fee row reads the plan again once it is topped up.
    func topUpBattery() {
        onRefillBattery { [weak self] in
            self?.prepareFeePlan(rereading: true)
        }
    }

    /// A battery that holds charges has nothing left to promote.
    func openBatteryPromo() {
        onRefillBattery { [weak self] in
            self?.batteryPromoCoverage = nil
            self?.render()
        }
    }

    /// A swap started from this screen could not go straight to the passcode, so it shows its
    /// pricing details instead.
    func confirmationDidShowPricingDetails() {
        confirmationPhase = .pricingDetails
    }

    /// A deposit made from the pricing details prepared the route again, and the fee row reads that plan. The
    /// amount takes the keyboard back unless a popup the swap left covers the screen.
    func confirmationDidClose(refocusesAmount: Bool = true) {
        confirmationPhase = nil
        confirmationAPIVersion = nil
        if refocusesAmount {
            requestFocusOnAppear()
        }
        setQuoteHeld(false)
        prepareFeePlan(rereading: true)
    }

    /// A swap on its way pins the quote it was confirmed with: neither refreshed nor expired meanwhile, and
    /// refreshed on release if its countdown or its route ran out.
    func setQuoteHeld(_ isHeld: Bool) {
        guard quoteViewModel.isSuspended != isHeld else {
            return
        }
        quoteViewModel.isSuspended = isHeld
        let now = now()
        let isCountdownOver = quoteRefreshCycle.map { $0.startDate.addingTimeInterval($0.duration) <= now } ?? false
        let isRouteExpired = quoteSnapshot.selectedRoute.map { $0.dateExpire <= now } ?? false
        guard !isHeld, isCountdownOver || isRouteExpired else {
            return
        }
        requestFreshQuote()
    }

    /// A fresh route the confirmation fetched after the screen's one went stale.
    func adoptConfirmationQuote(_ quoteState: MultichainSwapConfirmationQuoteState) {
        quoteViewModel.adopt(quote: quoteState.quote, route: quoteState.route)
    }

    var quoteRefreshCycle: MultichainSwapQuoteRefreshCycle? {
        quoteSnapshot.progressStartDate.map {
            MultichainSwapQuoteRefreshCycle(startDate: $0, duration: refreshDuration(from: $0))
        }
    }

    func setSlippageBps(_ bps: Int) {
        guard var inputs, inputs.slippageBps != bps else {
            return
        }
        inputs.slippageBps = bps
        commit(inputs, resettingQuote: true)
        refreshQuote(recreatePair: true, debounce: false)
    }

    func setFeeMethod(_ method: MultichainSwapFeeMethod?) {
        inputs?.feeMethod = method
        render()
    }

    func requestFreshQuote() {
        refreshQuote(recreatePair: false, debounce: false)
    }

    func quoteCountdownDidFinish() {
        guard case let .loaded(loadedState) = state,
              loadedState.quote.quoteState == .ready,
              !quoteViewModel.isSuspended
        else {
            return
        }
        quoteViewModel.notifyCircularProgressCompleted()
    }

    func swapDidFailToSend(_ failure: MultichainSwapSendFailure) {
        sendFailureTask?.cancel()
        sendFailure = failure
        guard case .retryable = failure else {
            return
        }
        sendFailureTask = Task { [weak self, wait = sendFailureWait] in
            do {
                try await wait(Self.sendFailureNanoseconds)
            } catch {
                return
            }
            self?.sendFailure = nil
        }
    }

    func swapTokens() {
        guard var inputs else {
            return
        }
        let previousSendAsset = inputs.sendAsset
        let previousSendCryptoAmount = calculator.sourceAmount(
            inputs: inputs,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        ).flatMap { sourceAmount -> String? in
            guard sourceAmount > 0 else {
                return nil
            }
            return calculator.cryptoInputAmountString(
                amount: sourceAmount,
                decimals: previousSendAsset.asset.decimals
            )
        } ?? ""
        let previousReceiveAmount = inputs.receiveAmount
        let receiveAmountIsZero = (calculator.cryptoAmount(
            text: previousReceiveAmount,
            decimals: inputs.receiveAsset.asset.decimals
        ) ?? 0) == 0

        inputs = inputs.settingSendAsset(inputs.receiveAsset)
        inputs.receiveAsset = previousSendAsset
        inputs.sendAmountInputMode = .crypto
        inputs.receiveAmountInputMode = .crypto
        // With nothing to move across (no quote yet, or it failed) the typed amount stays
        // in place instead of being wiped, and the new pair is re-quoted for it.
        inputs = inputs
            .settingSendAmount(receiveAmountIsZero ? previousSendCryptoAmount : previousReceiveAmount)
            .settingQuotedAmount("")
        commit(inputs, resettingQuote: true)

        refreshQuote(recreatePair: true, debounce: false)
        if !receiveAmountIsZero {
            carryReceiveAmount(previousSendCryptoAmount)
        }
    }

    func requestPickSendToken() {
        guard inputs != nil else {
            return
        }
        onRequestPickSendToken?()
    }

    func requestPickReceiveToken() {
        guard inputs != nil else {
            return
        }
        onRequestPickReceiveToken?()
    }

    func updateSendAmount(_ sendAmount: String) {
        guard var inputs, inputs.sendAmount != sendAmount else {
            return
        }
        inputs = inputs.settingSendAmount(sendAmount)
        commit(inputs)
        refreshQuote(recreatePair: false, debounce: true)
    }

    func updateReceiveAmount(_ receiveAmount: String) {
        guard let inputs,
              inputs.receiveAmount != receiveAmount,
              stateMaker.acceptsReceiveAmount(inputs)
        else {
            return
        }
        commit(inputs.settingReceiveAmount(receiveAmount))
        refreshQuote(recreatePair: false, debounce: true)
    }

    func applySendAsset(_ asset: MultichainAsset) {
        guard var inputs else {
            return
        }
        let previousSendAsset = inputs.sendAsset
        inputs = inputs.settingSendAsset(asset)
        let flipped = inputs.receiveAsset.asset.assetId == asset.asset.assetId
        if flipped {
            inputs.receiveAsset = previousSendAsset
        }
        inputs = normalizedInputModes(inputs)
        inputs = clearingQuotedAmount(inputs)
        commit(inputs, resettingQuote: true)

        refreshQuote(recreatePair: true, debounce: false)
    }

    func applyReceiveAsset(_ asset: MultichainAsset) {
        guard var inputs else {
            return
        }
        let previousReceiveAsset = inputs.receiveAsset
        inputs.receiveAsset = asset
        let flipped = inputs.sendAsset.asset.assetId == asset.asset.assetId
        if flipped {
            inputs = inputs.settingSendAsset(previousReceiveAsset)
        }
        inputs = normalizedInputModes(inputs)
        inputs = clearingQuotedAmount(inputs)
        commit(inputs, resettingQuote: true)

        refreshQuote(recreatePair: true, debounce: false)
    }

    /// A share of what Max would sell, so the presets keep the same fee reserve.
    func applySendPercent(_ percent: Int) {
        guard var inputs else {
            return
        }
        let maxAmount = MultichainSwapMaxAmount.maxSwapInputAmount(for: inputs.sendAsset)
        guard maxAmount > 0 else {
            if MultichainSwapMaxAmount.tonMaxUnavailableDueToFeeReserve(for: inputs.sendAsset) {
                onTonMaxAmountUnavailable()
            }
            return
        }
        inputs = inputs.settingSendAmount(
            calculator.inputAmountString(
                sourceAmount: maxAmount * BigUInt(percent) / 100,
                mode: inputs.sendAmountInputMode,
                asset: inputs.sendAsset,
                usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
            ),
            isMax: percent == 100
        )
        commit(inputs)
        refreshQuote(recreatePair: false, debounce: true)
    }

    func toggleSendAmountInputMode() {
        guard var inputs else {
            return
        }
        let nextMode = inputs.sendAmountInputMode.toggled
        guard nextMode != .fiat || calculator.fiatRates.hasFiatPrice(
            for: inputs.sendAsset,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        ) else {
            return
        }
        let sourceAmount = calculator.sourceAmount(
            inputs: inputs,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        )
        inputs = inputs.switchingSendAmountInputMode(
            to: nextMode,
            convertedAmount: inputs.sendAmount.isEmpty ? "" : calculator.inputAmountString(
                sourceAmount: sourceAmount ?? .zero,
                mode: nextMode,
                asset: inputs.sendAsset,
                usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
            )
        )
        if inputs.enteredField == .receive {
            // A ready route gives its amount in the new currency exactly, where the rounded text cannot.
            inputs = inputs.settingQuotedAmount(stateMaker.resolvedQuotedAmount(inputs: inputs, quote: quoteSnapshot))
        }
        commit(inputs)
        // Switching the currency the amount is written in leaves the amount itself alone,
        // so a ready quote is kept instead of being dropped for an identical one. A quoted
        // send amount is not asked for at all.
        guard inputs.enteredField == .send,
              calculator.sourceAmount(
                  inputs: inputs,
                  usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
              ) != sourceAmount
        else {
            return
        }
        refreshQuote(recreatePair: false, debounce: true)
    }

    func toggleReceiveAmountInputMode() {
        guard var inputs else {
            return
        }
        let nextMode = inputs.receiveAmountInputMode.toggled
        guard nextMode != .fiat || calculator.fiatRates.canRenderFiat(
            for: inputs.receiveAsset,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs),
            fallbackUsdPrice: quoteSnapshot.destinationUsdPrice
        ) else {
            return
        }
        inputs.receiveAmountInputMode = nextMode
        commit(inputs)
    }

    func makeConfirmationInput() -> MultichainSwapConfirmationInput? {
        guard case let .loaded(loadedState) = state, let inputs else {
            return nil
        }
        guard let selectedQuote = loadedState.quote.selectedQuote,
              let selectedRoute = loadedState.quote.selectedRoute,
              loadedState.validationState == .valid,
              loadedState.quote.quoteState == .ready,
              selectedRoute.dateExpire > now()
        else {
            return nil
        }
        guard let requestedAmount = quoteAmount(for: inputs) else {
            return nil
        }
        let confirmedAmount: MultichainSwapQuoteAmount = switch requestedAmount {
        case let .source(requested):
            .source(MultichainSwapSourceCharge.tradeAmount(requested: requested, route: selectedRoute))
        case .destination:
            requestedAmount
        }
        let input = MultichainSwapConfirmationInput(
            userInput: MultichainSwapConfirmationUserInput(
                quoteAmount: confirmedAmount,
                sendAsset: inputs.sendAsset,
                receiveAsset: inputs.receiveAsset,
                slippage: inputs.slippage,
                isMax: inputs.isMaxSend,
                slippageBps: quotedSlippageBps(for: inputs),
                feeMethod: inputs.feeMethod,
                usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
            ),
            quoteState: MultichainSwapConfirmationQuoteState(
                quote: selectedQuote,
                route: selectedRoute
            )
        )
        guard input.sourceAmount > 0,
              input.sourceAmount <= inputs.sendAsset.balance,
              BigUInt(selectedRoute.estimatedDestinationAmount) != nil
        else {
            return nil
        }
        return input
    }
}

private extension MultichainSwapViewModel {
    /// What the confirmation opened for, `nil` when it did not open.
    @discardableResult
    func openConfirmation(_ phase: MultichainSwapConfirmationPhase) -> MultichainSwapConfirmationInput? {
        guard confirmationPhase == nil,
              sendFailure == nil,
              let input = makeConfirmationInput(),
              let quoteRefreshCycle
        else {
            return nil
        }
        Log.multichainSwap.i(
            "swap confirmation opened: \(input.quoteState.quote.quoteId) / \(input.quoteState.route.routeId)",
            extraInfo: ["phase": "\(phase)"]
        )
        confirmationPhase = phase
        confirmationAPIVersion = input.quoteState.route.apiVersion
        onOpenConfirmation(input, quoteRefreshCycle, phase)
        return input
    }

    func commit(_ inputs: MultichainSwapInputs, resettingQuote: Bool = false) {
        if let sendFailure, sendFailure != .outcomeUnknown || !isSameSwap(self.inputs, inputs) {
            sendFailureTask?.cancel()
            self.sendFailure = nil
        }
        self.inputs = inputs
        if resettingQuote {
            quoteSnapshot = .initial()
        }
        render()
    }

    /// The fiat or crypto entry of an amount and the slippage leave the swap itself as it was.
    func isSameSwap(_ lhs: MultichainSwapInputs?, _ rhs: MultichainSwapInputs) -> Bool {
        guard let lhs else {
            return false
        }
        return lhs.sendAsset.asset.assetId == rhs.sendAsset.asset.assetId
            && lhs.receiveAsset.asset.assetId == rhs.receiveAsset.asset.assetId
            && quoteAmount(for: lhs) == quoteAmount(for: rhs)
    }

    /// The screen's quote refreshes when its countdown runs out; the pricing details show that countdown.
    /// A timer rather than `Task.sleep`, whose dispatch leeway lets a 30 s wait run a second or more late.
    func scheduleQuoteCountdown() {
        quoteCountdownTimer?.invalidate()
        quoteCountdownTimer = nil
        guard let quoteRefreshCycle else {
            return
        }
        let timer = Timer(
            fire: quoteRefreshCycle.startDate.addingTimeInterval(quoteRefreshCycle.duration),
            interval: 0,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.quoteCountdownDidFinish()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        quoteCountdownTimer = timer
    }

    /// The battery promo counts as shown once it is on screen, and stays for this screen's life.
    func render() {
        guard let inputs else {
            return
        }
        let showsBatteryPromo = quoteSnapshot.quoteState == .idle && batteryPromoCoverage?(inputs.sendAsset) == true
        state = .loaded(
            stateMaker.make(
                inputs: inputs,
                quote: quoteSnapshot,
                feePlan: shownFeePlan,
                showsBatteryPromo: showsBatteryPromo
            )
        )
        if showsBatteryPromo, !isBatteryPromoShown {
            isBatteryPromoShown = true
            batteryPromo?.markShown()
        }
        if confirmationPhase != nil {
            onConfirmationQuoteChange?(confirmationQuoteUpdate)
        }
    }

    func loadBatteryPromo() {
        guard let batteryPromo else {
            return
        }
        batteryPromoTask = Task { [weak self] in
            let coverage = await batteryPromo.load()
            guard !Task.isCancelled, let self, let coverage else {
                return
            }
            batteryPromoCoverage = coverage
            render()
        }
    }

    var shownFeePlan: MultichainSwapFeePlan {
        guard let feePlan, feePlan.routeId == quoteSnapshot.selectedRoute?.routeId else {
            return .preparing
        }
        return feePlan.plan
    }

    /// The fee row reads the plan of the ready route on screen, the one the confirmation prepares too.
    /// Offline nothing is prepared: the last route stays on screen with the plan it had. Rereading keeps
    /// the plan shown until the new answer replaces it. Preparation builds a real transaction, so an amount
    /// above the balance must not reach the provider just to estimate its fee.
    func prepareFeePlan(rereading: Bool = false) {
        guard let planProvider,
              let inputs,
              case let .loaded(loadedState) = state,
              loadedState.validationState.canEstimateFee,
              quoteSnapshot.quoteState == .ready,
              let route = quoteSnapshot.selectedRoute
        else {
            return
        }
        let isShownRoute = feePlan?.routeId == route.routeId
        guard rereading || !isShownRoute else {
            return
        }
        feePlanTask?.cancel()
        if !isShownRoute {
            feePlan = (route.routeId, .preparing)
        }
        let sourceAsset = inputs.sendAsset
        let destinationAsset = inputs.receiveAsset
        feePlanTask = Task { [weak self] in
            let plan: MultichainSwapFeePlan
            do throws(MultichainSwapExecutionFailure) {
                let executionPlan = try await planProvider.plan(
                    sourceAsset: sourceAsset,
                    destinationAsset: destinationAsset,
                    route: route
                )
                plan = .ready(feeOptions: executionPlan.feeOptions, networkFees: executionPlan.networkFees)
            } catch {
                if case let .insufficientNativeFee(shortage) = error {
                    plan = .nativeFeeShortage(shortage)
                } else {
                    plan = .failed
                }
            }
            guard !Task.isCancelled, let self, feePlan?.routeId == route.routeId else {
                return
            }
            feePlan = (route.routeId, plan)
            render()
        }
    }

    /// The backend gives a route the same minute a refresh waits, counted from before the quote got here:
    /// a refresh that waited all of it would find the route expired and the quote failed.
    func refreshDuration(from startDate: Date) -> TimeInterval {
        guard let dateExpire = quoteSnapshot.selectedRoute?.dateExpire else {
            return quoteRefreshDuration
        }
        let routeLifetime = dateExpire.timeIntervalSince(startDate) - Self.routeExpiryMargin
        return min(quoteRefreshDuration, max(routeLifetime, Self.minimumRefreshDuration))
    }

    var confirmationQuoteUpdate: MultichainSwapConfirmationQuoteUpdate {
        switch quoteSnapshot.quoteState {
        case .idle, .loading:
            return .loading
        case let .failed(failure):
            return .failed(.quote(failure))
        case .ready:
            guard let input = makeConfirmationInput(), let quoteRefreshCycle else {
                guard case let .loaded(loadedState) = state,
                      loadedState.validationState == .insufficientBalance
                else {
                    return .failed(.quote(.unavailable))
                }
                return .failed(.insufficientBalance)
            }
            return .ready(input, quoteRefreshCycle)
        }
    }

    func effectiveUsdFiatRate(inputs: MultichainSwapInputs) -> Decimal? {
        calculator.fiatRates.effectiveUsdFiatRate(inputs: inputs, quote: quoteSnapshot)
    }

    /// Realigns both amount fields to crypto when an asset change — including a
    /// flip that swaps both sides — leaves a field in fiat mode for an asset that
    /// can no longer be priced. Send fiat text is dropped since it cannot be
    /// reinterpreted as crypto; the receive amount is always stored as crypto.
    func normalizedInputModes(_ inputs: MultichainSwapInputs) -> MultichainSwapInputs {
        var inputs = inputs
        let usdFiatRate = effectiveUsdFiatRate(inputs: inputs)
        if inputs.sendAmountInputMode == .fiat,
           !calculator.fiatRates.canRenderFiat(for: inputs.sendAsset, usdFiatRate: usdFiatRate)
        {
            inputs.sendAmountInputMode = .crypto
            inputs = inputs.enteredField == .send
                ? inputs.settingSendAmount("")
                : inputs.settingQuotedAmount("")
        }
        if inputs.receiveAmountInputMode == .fiat,
           !calculator.fiatRates.canRenderFiat(for: inputs.receiveAsset, usdFiatRate: usdFiatRate)
        {
            inputs.receiveAmountInputMode = .crypto
        }
        return inputs
    }

    func applyQuoteSnapshot(_ snapshot: MultichainSwapQuoteSnapshot) {
        let wasOffline = quoteSnapshot.quoteState == .failed(.offline)
        quoteSnapshot = snapshot
        guard let inputs else {
            return
        }
        let resolvedInputs = inputs.settingQuotedAmount(
            stateMaker.resolvedQuotedAmount(inputs: inputs, quote: snapshot)
        )
        self.inputs = resolvedInputs
        // Rendered first: the plan is prepared only for what the new quote validates.
        render()
        prepareFeePlan()
        logFiatContextIfQuoteReady(inputs: resolvedInputs, snapshot: snapshot)
        if snapshot.quoteState == .failed(.offline), !wasOffline {
            onQuoteOffline()
        }
    }

    /// An asset change keeps the entered amount and asks for the quoted one again. An amount to
    /// receive the new pair cannot be quoted by goes, together with what was quoted for it.
    func clearingQuotedAmount(_ inputs: MultichainSwapInputs) -> MultichainSwapInputs {
        guard inputs.enteredField == .receive,
              !stateMaker.exactOutputSupport.supports(sendAsset: inputs.sendAsset, receiveAsset: inputs.receiveAsset)
        else {
            return inputs.settingQuotedAmount("")
        }
        return inputs.settingSendAmount("").settingQuotedAmount("")
    }

    /// Diagnostic trail for missing fiat lines: every input of the fiat
    /// resolution in one line, logged once per ready quote.
    func logFiatContextIfQuoteReady(
        inputs: MultichainSwapInputs,
        snapshot: MultichainSwapQuoteSnapshot
    ) {
        guard snapshot.quoteState == .ready else {
            return
        }
        var rateTextResolved = "n/a"
        if case let .loaded(loadedState) = state {
            rateTextResolved = loadedState.receiveCardRateText == nil ? "nil" : "present"
        }
        Log.multichainSwap.i(
            "quote fiat context",
            extraInfo: [
                "displayCurrency": calculator.displayCurrency.code,
                "usdFiatRate": inputs.usdFiatRate?.description ?? "nil",
                "sourceUsdPrice": snapshot.sourceUsdPrice.map { "\($0)" } ?? "nil",
                "destinationUsdPrice": snapshot.destinationUsdPrice.map { "\($0)" } ?? "nil",
                "receiveAssetPriceKeys": inputs.receiveAsset.price.prices.keys.sorted().joined(separator: ","),
                "receiveAmountText": inputs.receiveAmount,
                "receiveCardRateText": rateTextResolved,
            ]
        )
    }

    func carryReceiveAmount(_ receiveAmount: String) {
        guard let inputs,
              quoteSnapshot.quoteState != .ready,
              inputs.receiveAmount != receiveAmount
        else {
            return
        }
        self.inputs = inputs.settingQuotedAmount(receiveAmount)
        render()
    }
}

private extension MultichainSwapViewModel {
    func loadInitialAssets() {
        initialAssetsTask?.cancel()
        inputs = nil
        quoteSnapshot = .initial()
        state = .shimmer
        quoteViewModel.reset()

        let defaultAssetsService = defaultAssetsService
        initialAssetsTask = Task { [weak self] in
            do {
                let initialAssets = try await defaultAssetsService.load()
                guard !Task.isCancelled, let self else {
                    return
                }
                applyInitialAssets(initialAssets)
            } catch {
                guard !Task.isCancelled, let self else {
                    return
                }
                Log.multichainSwap.w("initial assets loading failed", error: error)
                state = .error
            }
        }
    }

    func applyInitialAssets(_ initialAssets: MultichainSwapInitialAssets) {
        commit(MultichainSwapInputs(initialAssets: initialAssets), resettingQuote: true)
        refreshQuote(recreatePair: true, debounce: false)
        if initialAssets.hasUnavailableInitialSelection {
            onInitialSelectionUnavailable()
        }
    }
}

private extension MultichainSwapViewModel {
    func refreshQuote(recreatePair: Bool, debounce: Bool) {
        guard let inputs else {
            quoteViewModel.setPair(nil)
            return
        }
        if recreatePair {
            quoteViewModel.setPair(pairContext(for: inputs))
        }
        quoteViewModel.updateAmount(
            quoteAmount(for: inputs),
            isMax: inputs.isMaxSend,
            debounce: debounce
        )
    }

    func pairContext(for inputs: MultichainSwapInputs) -> MultichainSwapQuotePairContext? {
        guard let sourceChain = inputs.sendAsset.asset.chain,
              let destinationChain = inputs.receiveAsset.asset.chain,
              let senderAddress = swapWallet.address(for: sourceChain),
              let recipientAddress = swapWallet.address(for: destinationChain)
        else {
            return nil
        }
        return MultichainSwapQuotePairContext(
            source: MultichainSwapQuoteItem(
                assetId: inputs.sendAsset.asset.assetId,
                chain: sourceChain,
                address: senderAddress
            ),
            destination: MultichainSwapQuoteItem(
                assetId: inputs.receiveAsset.asset.assetId,
                chain: destinationChain,
                address: recipientAddress
            ),
            slippageBps: quotedSlippageBps(for: inputs),
            walletId: swapWallet.walletId,
            apiVersion: confirmationAPIVersion ?? swapWallet.swapAPIVersion(
                selling: inputs.sendAsset.asset,
                isV3Enabled: isSwapV3Enabled
            )
        )
    }

    func quotedSlippageBps(for inputs: MultichainSwapInputs) -> Int {
        inputs.slippageBps ?? DefaultMultichainSwapSlippageService(
            sourceAssetId: inputs.sendAsset.asset.assetId,
            sourceChain: inputs.sendAsset.asset.chain,
            slippage: inputs.slippage
        ).defaultBps
    }

    func quoteAmount(for inputs: MultichainSwapInputs) -> MultichainSwapQuoteAmount? {
        guard pairContext(for: inputs) != nil else {
            return nil
        }
        return calculator.enteredAmount(inputs: inputs, usdFiatRate: effectiveUsdFiatRate(inputs: inputs))
    }
}
