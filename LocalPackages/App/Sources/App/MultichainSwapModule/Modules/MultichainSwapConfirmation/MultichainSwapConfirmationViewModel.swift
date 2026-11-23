import Foundation
import KeeperCore
import OperationReviewModels
import TKCore
import TKLocalize
import TKLogging
import UIKit

@MainActor
final class MultichainSwapConfirmationViewModel: ObservableObject {
    @Published private(set) var display: MultichainSwapConfirmationDisplay
    @Published private(set) var executionState: MultichainSwapConfirmationExecutionState = .idle {
        didSet { updateSwapInFlight() }
    }

    @Published private(set) var selectedSlippageBps: Int {
        didSet { onSlippageChange(selectedSlippageBps) }
    }

    /// The swap screen's quote: the countdown both show while it is ready, and why it failed otherwise.
    /// A failure takes the confirm button's place until a new quote arrives.
    @Published private(set) var quoteStatus: MultichainSwapConfirmationQuoteStatus

    @Published private var pendingSwap: PendingSwap? {
        didSet { updateSwapInFlight() }
    }

    private(set) var slippageOptions: [Int]

    var onRequestSlippageSelection: ((UIView) -> Void)?

    private let swapWallet: MultichainSwapWallet
    private var input: MultichainSwapConfirmationInput
    private let amountFormatter: AmountFormatter
    private let priceImpactResolver: MultichainSwapConfirmationPriceImpactResolver
    private let displayMaker: MultichainSwapConfirmationDisplayMaker
    let refreshModel: MultichainSwapConfirmationRefreshModel
    private let executor: MultichainSwapConfirmationExecutor
    private let logInfoMaker: MultichainSwapConfirmationLogInfoMaker
    private let swapAnalytics: MultichainSwapAnalytics?
    private let onConfirm: () -> Void
    private let onPriceChanged: (_ message: String) -> Void
    private let onConfirmUnavailable: () -> Void
    private let onSwapInFlightChange: (Bool) -> Void
    private let onRefreshQuote: () -> Void
    private let onQuoteRecovered: (MultichainSwapConfirmationQuoteState) -> Void
    private let onSlippageChange: (Int) -> Void
    private let onFeeMethodChange: (MultichainSwapFeeMethod?) -> Void
    private let onExecutionCompleted: (MultichainSwapConfirmationInput, MultichainSwapFeeMethod, MultichainSwapExecutionResult) -> Void
    private let onExecutionFailed: (_ message: String, _ canRetry: Bool) -> Void
    private let onExecutionCanceled: () -> Void
    private let onPreparationFailed: (String) -> Void
    private let onInsufficientNativeFee: (MultichainNativeFeeShortage) -> Void
    private let onOpenFeePicker: (NetworkFeePickerPresentation) -> Void
    private let onRefillBattery: (@escaping () -> Void) -> Void
    private let onBatteryFeeShortage: (MultichainNativeFeeShortage) -> Void
    private let onDepositNativeFee: (MultichainAssetDetails) -> Void
    private var pickedFeeMethod: MultichainSwapFeeMethod? {
        didSet { onFeeMethodChange(pickedFeeMethod) }
    }

    /// What the last plan that priced this swap would have paid with, or `nil` if none of its methods
    /// could pay. Outlives the plan so a failed refresh cannot flash a shortage the relayer covers.
    private var lastCoveringFeeMethod: MultichainSwapFeeMethod?
    /// A relayed send whose outcome is unknown: this confirmation sends nothing more.
    private(set) var isRetryUnsafe = false
    private var executionPlan: MultichainSwapExecutionPlan?
    private var nativeFeeShortageForFeeDisplay: MultichainNativeFeeShortage?

    /// The route the user agreed to swap at, as it was priced then.
    private var priceImpactAcceptedRoute: MultichainSwapRoute?
    /// The swap screen counted the tap that started the swap as swap_click. A swap it could not send straight to
    /// the passcode goes on in the pricing details, and their first Swap tap continues it without counting another.
    private var isSwapClickCounted = false

    /// Why this confirmation asked the swap screen for a new quote, until that quote arrives.
    private var requestedRefreshReason: MultichainSwapConfirmationRefreshReason?
    /// A swap the user started is on its way: waiting for its plan, behind the price impact warning, or
    /// being sent. The swap screen holds its quote meanwhile, so a refresh cannot race the send.
    private var isSwapInFlight = false {
        didSet {
            if isSwapInFlight != oldValue {
                onSwapInFlightChange(isSwapInFlight)
            }
        }
    }

    init(
        swapWallet: MultichainSwapWallet,
        confirmationInput: MultichainSwapConfirmationInput,
        quoteRefreshCycle: MultichainSwapQuoteRefreshCycle,
        amountFormatter: AmountFormatter,
        executionService: MultichainSwapExecutionService,
        planProvider: MultichainSwapPlanProvider? = nil,
        multichainSwapService: MultichainSwapService,
        isSwapKitEnabled: Bool = false,
        slippageService: (any MultichainSwapSlippageService)? = nil,
        routeRecovery: MultichainSwapRouteRecovery = .default,
        displayCurrency: Currency = .USD,
        walletAsset: @escaping (_ assetId: String) -> MultichainAsset? = { _ in nil },
        swapAnalytics: MultichainSwapAnalytics? = nil,
        onConfirm: @escaping () -> Void = {},
        onPriceChanged: @escaping (_ message: String) -> Void = { _ in },
        onConfirmUnavailable: @escaping () -> Void = {},
        onSwapInFlightChange: @escaping (Bool) -> Void = { _ in },
        onRefreshQuote: @escaping () -> Void = {},
        onQuoteRecovered: @escaping (MultichainSwapConfirmationQuoteState) -> Void = { _ in },
        onSlippageChange: @escaping (Int) -> Void = { _ in },
        onFeeMethodChange: @escaping (MultichainSwapFeeMethod?) -> Void = { _ in },
        onExecutionCompleted: @escaping (
            MultichainSwapConfirmationInput,
            MultichainSwapFeeMethod,
            MultichainSwapExecutionResult
        ) -> Void = { _, _, _ in },
        onExecutionFailed: @escaping (_ message: String, _ canRetry: Bool) -> Void = { _, _ in },
        onExecutionCanceled: @escaping () -> Void = {},
        onPreparationFailed: @escaping (String) -> Void = { _ in },
        onInsufficientNativeFee: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onOpenFeePicker: @escaping (NetworkFeePickerPresentation) -> Void = { _ in },
        onRefillBattery: @escaping (@escaping () -> Void) -> Void = { _ in },
        onBatteryFeeShortage: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onDepositNativeFee: @escaping (MultichainAssetDetails) -> Void = { _ in }
    ) {
        self.swapWallet = swapWallet
        self.input = confirmationInput
        self.quoteStatus = .ready(quoteRefreshCycle)
        self.amountFormatter = amountFormatter
        let priceImpactResolver = MultichainSwapConfirmationPriceImpactResolver()
        let displayMaker = MultichainSwapConfirmationDisplayMaker(
            amountFormatter: amountFormatter,
            displayCurrency: displayCurrency,
            walletAsset: walletAsset
        )
        let logInfoMaker = MultichainSwapConfirmationLogInfoMaker(
            priceImpactResolver: priceImpactResolver
        )
        self.priceImpactResolver = priceImpactResolver
        self.displayMaker = displayMaker
        self.refreshModel = MultichainSwapConfirmationRefreshModel(
            swapWallet: swapWallet,
            quoteRefresher: MultichainSwapConfirmationQuoteRefresher(
                multichainSwapService: multichainSwapService,
                requestedAggregators: MultichainSwapQuoteRequest.requestedAggregators(
                    isSwapKitEnabled: isSwapKitEnabled
                )
            ),
            planProvider: planProvider ?? MultichainSwapPlanProvider(
                swapWallet: swapWallet,
                executionService: executionService
            ),
            routeRecovery: routeRecovery,
            logInfoMaker: logInfoMaker
        )
        self.executor = MultichainSwapConfirmationExecutor(
            executionService: executionService
        )
        self.logInfoMaker = logInfoMaker
        self.swapAnalytics = swapAnalytics
        let resolvedSlippageService: any MultichainSwapSlippageService
        if let slippageService {
            resolvedSlippageService = slippageService
        } else {
            resolvedSlippageService = DefaultMultichainSwapSlippageService(
                sourceAssetId: confirmationInput.userInput.sendAsset.asset.assetId,
                sourceChain: confirmationInput.userInput.sendAsset.asset.chain,
                slippage: confirmationInput.userInput.slippage
            )
        }
        self.slippageOptions = resolvedSlippageService.optionsBps
        let selectedSlippageBps = confirmationInput.userInput.slippageBps
        self.selectedSlippageBps = selectedSlippageBps
        self.pickedFeeMethod = confirmationInput.userInput.feeMethod
        self.display = displayMaker.make(
            input: confirmationInput,
            networkFees: nil,
            selectedSlippageBps: selectedSlippageBps
        )
        self.onConfirm = onConfirm
        self.onPriceChanged = onPriceChanged
        self.onConfirmUnavailable = onConfirmUnavailable
        self.onSwapInFlightChange = onSwapInFlightChange
        self.onRefreshQuote = onRefreshQuote
        self.onQuoteRecovered = onQuoteRecovered
        self.onSlippageChange = onSlippageChange
        self.onFeeMethodChange = onFeeMethodChange
        self.onExecutionCompleted = onExecutionCompleted
        self.onExecutionFailed = onExecutionFailed
        self.onExecutionCanceled = onExecutionCanceled
        self.onPreparationFailed = onPreparationFailed
        self.onInsufficientNativeFee = onInsufficientNativeFee
        self.onOpenFeePicker = onOpenFeePicker
        self.onRefillBattery = onRefillBattery
        self.onBatteryFeeShortage = onBatteryFeeShortage
        self.onDepositNativeFee = onDepositNativeFee
        refreshModel.onQuoteStateChange = { [weak self] quoteState in
            guard let self else { return }
            input = MultichainSwapConfirmationInput(
                userInput: input.userInput,
                quoteState: quoteState
            )
            executionPlan = nil
            nativeFeeShortageForFeeDisplay = nil
            updateDisplay()
            onQuoteRecovered(quoteState)
        }
        refreshModel.onExecutionPlanChange = { [weak self] executionPlan in
            guard let self else { return }
            self.executionPlan = executionPlan
            // The backend may price a route again when it builds its operation: what is shown, asked
            // about and reported is what that operation receives.
            if let route = executionPlan?.preparedRoute, route.routeId == input.quoteState.route.routeId {
                input = MultichainSwapConfirmationInput(
                    userInput: input.userInput,
                    quoteState: MultichainSwapConfirmationQuoteState(quote: input.quoteState.quote, route: route)
                )
            }
            if let executionPlan {
                // Only a plan that genuinely no longer offers the picked method may drop it. A
                // refresh that produced no plan at all knows nothing about what can pay, and
                // clearing the pick there would silently hand the swap back to the relayer.
                if let pickedFeeMethod,
                   !executionPlan.feeOptions.contains(where: { $0.method == pickedFeeMethod })
                {
                    self.pickedFeeMethod = nil
                }
                lastCoveringFeeMethod = selectedFeeOption.flatMap { option in
                    option.isInsufficient ? nil : option.method
                }
                nativeFeeShortageForFeeDisplay = nil
                if case .preparationFailed = executionState {
                    executionState = .idle
                }
            }
            updateDisplay()
            if executionPlan != nil {
                resolvePendingConfirm()
            }
        }
        refreshModel.onPreparationFailure = { [weak self] reason, failure in
            self?.applyPreparationFailure(failure, reason: reason)
        }
        Log.multichainSwap.i(
            "confirmation view model initialized",
            extraInfo: confirmationLogInfo()
        )
    }

    var priceImpactSeverity: MultichainSwapPriceImpactSeverity {
        priceImpactResolver.severity(input: input)
    }

    var requiresPriceImpactWarning: Bool {
        priceImpactSeverity.requiresConfirmation
    }

    /// The user agreed to swap at the price impact of the route now shown, so the swap goes on without
    /// the warning, such as from the sheet that a plan unable to pay opens after it. A new route asks
    /// again, and so does the same one priced worse, as the operation prepared for it can be.
    var isPriceImpactAccepted: Bool {
        let route = input.quoteState.route
        guard let accepted = priceImpactAcceptedRoute, accepted.routeId == route.routeId else {
            return false
        }
        return (route.valueDifferenceBps ?? 0) >= (accepted.valueDifferenceBps ?? 0)
    }

    func acceptPriceImpact() {
        priceImpactAcceptedRoute = input.quoteState.route
    }

    /// A Swap tap waiting for its plan would otherwise go on to the passcode with the quote the new
    /// slippage brings, which nobody tapped Swap for.
    var canSelectSlippage: Bool {
        slippageOptions.count > 1 && executionState.isConfirmEnabled && !isConfirmPending
    }

    /// Follows the swap screen's Swap button: on while the quote is ready, also before its plan is
    /// prepared and when nothing can pay the fee. A tap meanwhile waits for the plan, or opens the way
    /// to pay the fee.
    var isSwapEnabled: Bool {
        guard case .ready = quoteStatus, !isRetryUnsafe else {
            return false
        }
        switch executionState {
        case .idle, .executionFailed:
            return true
        case .executing, .completed, .preparationFailed:
            return false
        }
    }

    /// A tap confirms right away: the quote's plan is prepared and can pay.
    var isConfirmEnabled: Bool {
        isSwapEnabled && executionPlan != nil && selectedFeeOption?.isInsufficient != true
    }

    /// Nothing can pay the fee, so a Swap tap opens the ways to pay it: Swap looks blocked meanwhile.
    var isFeeUnpaid: Bool {
        unpaidFee != nil
    }

    var isConfirmPending: Bool {
        if case .awaitingPlan = pendingSwap {
            return true
        }
        return false
    }

    var quoteFailureMessage: String? {
        guard case let .failed(message) = quoteStatus else {
            return nil
        }
        return message
    }

    var currentConfirmationInput: MultichainSwapConfirmationInput {
        input
    }

    /// The chain's own coin is the method that always exists, so it stands in while no plan has
    /// priced anything yet.
    var selectedFeeMethod: MultichainSwapFeeMethod {
        selectedFeeOption?.method ?? .native
    }

    var selectedFeeOption: MultichainSwapFeeOption? {
        MultichainSwapFeeSelection.resolve(
            options: executionPlan?.feeOptions ?? [],
            picked: pickedFeeMethod
        )
    }

    /// The selection stays on a battery that cannot pay only when nothing else can, so a top-up is
    /// what moves the swap on.
    var requiresBatteryTopUp: Bool {
        guard let selectedFeeOption else {
            return false
        }
        return selectedFeeOption.method.isBattery && selectedFeeOption.isInsufficient
    }

    func topUpBattery() {
        guard requiresBatteryTopUp, executionState.isConfirmEnabled else {
            return
        }
        refillBattery()
    }

    /// The fee row opens the picker, or, for the only method and one unable to pay, its refill straight away: a
    /// picker of one method would only lead there.
    func tapFeeMethod() {
        let options = executionPlan?.feeOptions ?? []
        guard options.count <= 1 else {
            openFeeMethodPicker(options: options)
            return
        }
        guard display.isNetworkFeeShortage, executionState.isConfirmEnabled else {
            return
        }
        if let nativeFeeShortageForFeeDisplay {
            onDepositNativeFee(nativeFeeShortageForFeeDisplay.asset)
        } else if let option = options.first {
            requestFeeRefill(for: option)
        }
    }

    func prepareExecutionPlan() {
        refreshModel.refreshExecutionPlan(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: .initial
        )
    }

    func updateQuote(_ update: MultichainSwapConfirmationQuoteUpdate) {
        // The swap screen holds its quote while a swap is sent, and a sent swap keeps the one it used.
        guard executionState != .executing, executionState != .completed else {
            return
        }
        switch update {
        case .loading:
            quoteStatus = .loading
        case let .ready(input, quoteRefreshCycle):
            let isShownQuote: Bool = {
                guard case .ready = quoteStatus else { return false }
                return input.quoteState.quote.quoteId == self.input.quoteState.quote.quoteId
                    && input.quoteState.route.routeId == self.input.quoteState.route.routeId
            }()
            quoteStatus = .ready(quoteRefreshCycle)
            // Only the countdown restarts for a quote already shown, such as a route this confirmation
            // recovered coming back from the swap screen.
            guard !isShownQuote else {
                return
            }
            self.input = input
            executionPlan = nil
            nativeFeeShortageForFeeDisplay = nil
            updateDisplay()
            let reason = requestedRefreshReason ?? .timer
            requestedRefreshReason = nil
            // The route was just quoted: a stale one here is a failure rather than a reason to ask again.
            refreshModel.refreshExecutionPlan(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                reason: reason,
                recoversStaleRoute: false
            )
        case let .failed(failure):
            requestedRefreshReason = nil
            refreshModel.cancel()
            executionPlan = nil
            quoteStatus = .failed(failure.message)
            updateDisplay()
            Log.multichainSwap.w(
                "confirmation locked after the swap screen's quote failed",
                extraInfo: confirmationLogInfo()
            )
            resolvePendingConfirm()
        }
    }

    /// For a swap started from the swap screen: confirms the first plan that arrives, opens the way to
    /// pay a fee nothing can pay, or hands it to `onConfirmUnavailable` when it cannot be confirmed.
    func confirmWhenReady() {
        isSwapClickCounted = true
        awaitPlan()
    }

    func refreshFeeCalculationAfterDeposit() {
        guard executionState != .executing, executionState != .completed else {
            return
        }
        refreshModel.refreshExecutionPlan(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: .feeDeposit
        )
    }

    /// The Swap button of the pricing details. A swap that starts here sends its own swap_click; the swap screen
    /// sends one for a swap it started, also when that swap goes on here.
    func confirm() {
        guard !isConfirmPending else {
            return
        }
        guard isSwapEnabled else {
            Log.multichainSwap.i(
                "confirmation ignored while the quote is not ready",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        // The pricing details can stay open past the deadline of the operation `/v3` built, which no quote
        // refresh follows: such a plan would only fail as expired, so the tap waits for the route prepared again.
        if let expiresAt = executionPlan?.expiresAt, expiresAt <= Date() {
            executionPlan = nil
            updateDisplay()
        }
        if let unpaidFee {
            reportUnpaidFee(unpaidFee)
            return
        }
        guard let executionPlan else {
            logSwapClick()
            awaitPlan()
            // Waiting holds the swap screen's quote, so no new quote would bring a plan: one that is not on
            // its way, such as after a preparation that ended without one, is asked for here.
            if !refreshModel.isPreparing {
                refreshModel.refreshExecutionPlan(
                    input: input,
                    selectedSlippageBps: selectedSlippageBps,
                    reason: .swapTap
                )
            }
            return
        }
        guard isConfirmEnabled else {
            return
        }
        logSwapClick()
        pinAndConfirm(executionPlan)
    }

    func retryQuote() {
        guard case .failed = quoteStatus else {
            return
        }
        quoteStatus = .loading
        requestFreshQuote(reason: .retry)
    }

    func requestSlippageSelection(sourceView: UIView) {
        guard canSelectSlippage else {
            return
        }
        onRequestSlippageSelection?(sourceView)
    }

    func slippageTitle(bps: Int) -> String {
        displayMaker.percentLine(bps: bps)
    }

    func selectSlippageBps(_ bps: Int) {
        guard canSelectSlippage else {
            Log.multichainSwap.i(
                "slippage selection ignored while confirmation is locked",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        guard selectedSlippageBps != bps else {
            return
        }
        // Reported through `onSlippageChange`: the swap screen asks for the quote with it.
        requestedRefreshReason = .slippageChanged
        refreshModel.cancel()
        selectedSlippageBps = bps
        quoteStatus = .loading
        executionPlan = nil
        nativeFeeShortageForFeeDisplay = nil
        updateDisplay()
    }

    func selectFeeOption(_ option: MultichainSwapFeeOption) {
        guard executionState.isConfirmEnabled else {
            return
        }
        guard !option.isInsufficient else {
            requestFeeRefill(for: option)
            return
        }
        guard pickedFeeMethod != option.method else {
            return
        }
        pickedFeeMethod = option.method
        nativeFeeShortageForFeeDisplay = nil
        updateDisplay()
    }

    /// Backing out of the confirmation drops the swap that is pinned or still waits for its plan, and with
    /// it the hold on the swap screen's quote, which refreshes at once if its countdown ran out meanwhile.
    func cancelConfirm() {
        pendingSwap = nil
    }

    func execute(signer: MultichainTransferSigner, consent: OperationConsent) {
        guard executionState != .executing else {
            Log.multichainSwap.i(
                "execution request ignored while already executing",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        guard case let .confirmed(confirmed) = pendingSwap else {
            Log.multichainSwap.i(
                "execution skipped: no confirmed swap to send",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        // Executing before the pin is dropped, so the swap never stops being in flight in between.
        executionState = .executing
        pendingSwap = nil
        Log.multichainSwap.i(
            "execution requested from confirmation",
            extraInfo: confirmationLogInfo(
                additional: ["feeMethod": "\(confirmed.feeMethod)"]
            )
        )
        refreshModel.cancel()
        isRetryUnsafe = false
        swapAnalytics?.logConfirm(confirmed.input, feeMethod: confirmed.feeMethod)
        Task { [weak self] in
            guard let self else { return }
            let result = await executor.execute(
                signer: signer,
                swapWallet: swapWallet,
                input: confirmed.input,
                executionPlan: confirmed.executionPlan,
                feeMethod: confirmed.feeMethod,
                consent: consent
            )
            switch result {
            case let .success(result):
                self.applyExecutionResult(result, confirmed: confirmed)
            case let .failure(failure):
                self.applyExecutionFailure(failure, confirmed: confirmed)
            }
        }
    }
}

private extension MultichainSwapConfirmationViewModel {
    /// The plan answers a tap that waited for it: the way to pay a fee nothing pays, the sheet when the swap
    /// cannot go on, else the passcode, asked about first when a route recovered meanwhile prices the swap
    /// worse than the one tapped for.
    func resolvePendingConfirm() {
        guard case let .awaitingPlan(tappedRoute) = pendingSwap else {
            return
        }
        if isSwapEnabled, let unpaidFee {
            pendingSwap = nil
            reportUnpaidFee(unpaidFee)
            return
        }
        guard let executionPlan, isConfirmEnabled else {
            pendingSwap = nil
            onConfirmUnavailable()
            return
        }
        pin(executionPlan)
        guard let priceChange = displayMaker.priceChange(from: tappedRoute, to: input) else {
            onConfirm()
            return
        }
        Log.multichainSwap.w(
            "recovered route priced the swap worse than the tapped one",
            extraInfo: confirmationLogInfo(additional: ["tappedRouteId": tappedRoute.routeId])
        )
        onPriceChanged(priceChange)
    }

    func pinAndConfirm(_ executionPlan: MultichainSwapExecutionPlan) {
        pin(executionPlan)
        onConfirm()
    }

    func awaitPlan() {
        pendingSwap = .awaitingPlan(tappedRoute: input.quoteState.route)
        if executionPlan != nil {
            resolvePendingConfirm()
        }
    }

    func logSwapClick() {
        guard !isSwapClickCounted else {
            isSwapClickCounted = false
            return
        }
        swapAnalytics?.logClick(input)
    }

    /// A warning can stand between the tap and the send. Pin what the rows showed: the swap is sent with
    /// the plan and the fee method the user agreed to, or not at all.
    func pin(_ executionPlan: MultichainSwapExecutionPlan) {
        pendingSwap = .confirmed(
            ConfirmedSwap(
                input: input,
                executionPlan: executionPlan,
                feeMethod: selectedFeeMethod
            )
        )
        refreshModel.cancel()
        Log.multichainSwap.i(
            "confirmation accepted",
            extraInfo: confirmationLogInfo(
                additional: [
                    "requiresPriceImpactWarning": requiresPriceImpactWarning ? "true" : "false",
                    "feeMethod": "\(selectedFeeMethod)",
                ]
            )
        )
    }

    func requestFreshQuote(reason: MultichainSwapConfirmationRefreshReason) {
        requestedRefreshReason = reason
        onRefreshQuote()
    }

    func updateSwapInFlight() {
        isSwapInFlight = pendingSwap != nil
            || executionState == .executing
            || executionState == .completed
    }

    func updateDisplay() {
        display = displayMaker.make(
            input: input,
            networkFees: networkFeesForDisplay,
            feeOptions: executionPlan?.feeOptions ?? [],
            selectedFeeOption: selectedFeeOption,
            selectedSlippageBps: selectedSlippageBps,
            nativeFeeShortage: nativeFeeShortageForFeeDisplay
        )
    }

    /// A plan that drops the relayed option really does leave nothing paying, so the shortage has to
    /// reach the user again. A refresh that produced no plan at all says nothing about what can pay,
    /// and the last one that priced the swap still answers for it.
    var isRelayedFeeCovering: Bool {
        guard let option = selectedFeeOption else {
            return lastCoveringFeeMethod?.isRelayed == true
        }
        return option.method.isRelayed && !option.isInsufficient
    }

    /// What a Swap tap opens when nothing can pay the fee: the battery's refill beside the deposit of the
    /// chain's coin where the plan offers the battery, else the deposit alone. A shortage the chain's coin
    /// ran into outranks the plan priced before it. `nil` while something pays, and when only a battery
    /// top-up could, which the confirm button offers itself.
    var unpaidFee: UnpaidFee? {
        if let nativeFeeShortageForFeeDisplay {
            return .nativeCoin(nativeFeeShortageForFeeDisplay)
        }
        guard let feeOptions = executionPlan?.feeOptions,
              !feeOptions.contains(where: { !$0.isInsufficient }),
              let nativeFee = feeOptions.first(where: { $0.method == .native })?.feeAmounts?.first
        else {
            return nil
        }
        let shortage = executionPlan?.nativeFeeShortage ?? MultichainNativeFeeShortage(asset: nativeFee.asset, requiredAmount: nativeFee.amount)
        return feeOptions.contains(where: { $0.method.isBattery }) ? .battery(shortage) : .nativeCoin(shortage)
    }

    func reportUnpaidFee(_ unpaidFee: UnpaidFee) {
        switch unpaidFee {
        case let .battery(shortage):
            onBatteryFeeShortage(shortage)
        case let .nativeCoin(shortage):
            onInsufficientNativeFee(shortage)
        }
    }

    func openFeeMethodPicker(options: [MultichainSwapFeeOption]) {
        let selectedMethod = selectedFeeOption?.method
        // A swap prices each method at most once, so the method identifies its row: a position would
        // resolve against whichever list the picker was built from rather than what was tapped.
        let items = options.map { option in
            let isShortBattery = option.isInsufficient && option.method.isBattery
            // An unpriced battery may hold charges, so it is not told short of them.
            let lacksCharges = if case .batteryCharges(_, _, isInsufficient: true) = option.cost { true } else { false }
            return NetworkFeePickerItem(
                id: option.method.id,
                leading: option.extraType.networkFeePickerLeading,
                text: .titled(
                    title: option.extraType.feeRowMethodTitle,
                    subtitle: displayMaker.feePickerSubtitle(option, input: input)
                ),
                isDisabled: option.isInsufficient,
                warning: lacksCharges ? TKLocales.FeeMethodPicker.notEnough : nil,
                actionTitle: option.isInsufficient
                    ? (isShortBattery ? TKLocales.FeeMethodPicker.topUp : TKLocales.FeeMethodPicker.deposit)
                    : nil,
                // A short battery leads to its top-up, so its row is not marked as the pick.
                isSelected: option.method == selectedMethod && !isShortBattery
            )
        }
        onOpenFeePicker(
            NetworkFeePickerPresentation(
                configuration: NetworkFeePickerConfiguration(
                    title: TKLocales.FeeMethodPicker.title,
                    subtitle: TKLocales.FeeMethodPicker.subtitle
                ),
                dataSource: StaticNetworkFeePickerDataSource(items: items),
                didSelectItem: { [weak self] item, _ in
                    guard let self,
                          let method = MultichainSwapFeeMethod(id: item.id),
                          let option = options.first(where: { $0.method == method })
                    else {
                        return
                    }
                    selectFeeOption(option)
                }
            )
        )
    }

    func requestFeeRefill(for option: MultichainSwapFeeOption) {
        guard let asset = option.depositAsset else {
            refillBattery()
            return
        }
        onDepositNativeFee(asset)
    }

    func refillBattery() {
        onRefillBattery { [weak self] in
            self?.refreshFeeCalculationAfterDeposit()
        }
    }

    var networkFeesForDisplay: [MultichainTransactionEmulationResult]? {
        if let executionPlan {
            return executionPlan.networkFees
        }
        guard let nativeFeeShortageForFeeDisplay else {
            return nil
        }
        return [
            MultichainTransactionEmulationResult(
                fee: nativeFeeShortageForFeeDisplay.requiredAmount,
                asset: nativeFeeShortageForFeeDisplay.asset
            ),
        ]
    }

    func confirmationLogInfo(additional: [String: String] = [:]) -> [String: String] {
        logInfoMaker.make(input: input, additional: additional)
    }

    func applyExecutionResult(_ result: MultichainSwapExecutionResult, confirmed: ConfirmedSwap) {
        executionState = .completed
        Log.multichainSwap.i(
            "execution completed in confirmation",
            extraInfo: confirmationLogInfo(additional: ["txHash": result.txHash ?? "none"])
        )
        swapAnalytics?.logSuccess(confirmed.input, feeMethod: confirmed.feeMethod)
        onExecutionCompleted(confirmed.input, confirmed.feeMethod, result)
    }

    func applyExecutionFailure(_ failure: MultichainSwapExecutionFailure, confirmed: ConfirmedSwap) {
        if failure != .canceled {
            swapAnalytics?.logFailure(confirmed.input, feeMethod: confirmed.feeMethod, failure: failure)
        }
        if case let .insufficientNativeFee(shortage) = failure {
            executionState = .idle
            applyInsufficientNativeFee(shortage, stage: "execution")
            if let unpaidFee {
                reportUnpaidFee(unpaidFee)
            }
            return
        }
        guard let message = failure.confirmationUserMessage else {
            executionState = .idle
            Log.multichainSwap.i(
                "execution canceled in confirmation",
                extraInfo: confirmationLogInfo()
            )
            onExecutionCanceled()
            return
        }
        // A relayed swap whose outcome is unknown must not be re-armed: signing again would send a
        // second, equally valid message once the first one lands and moves the seqno.
        isRetryUnsafe = confirmed.feeMethod.isRelayed && failure.isBroadcastOutcomeUnknown
        executionState = .executionFailed(message)
        Log.multichainSwap.w(
            "execution failed in confirmation",
            error: failure,
            extraInfo: confirmationLogInfo(
                additional: ["retryUnsafe": isRetryUnsafe ? "true" : "false"]
            )
        )
        // Asked before the failure is reported: without the sheet the report ends the confirmation, and a
        // request made after it would reach nobody.
        if !isRetryUnsafe {
            requestFreshQuote(reason: .executionFailed)
        }
        onExecutionFailed(message, !isRetryUnsafe)
    }

    /// Without a plan the sheet has nothing to confirm and nothing to offer: the fee stays unpriced and
    /// the confirm button locked. A shortage of the chain's coin is the exception, since a Swap tap opens
    /// the deposit that clears it; any other failure goes back to the swap screen, which quotes afresh.
    func applyPreparationFailure(
        _ failure: MultichainSwapExecutionFailure,
        reason: MultichainSwapConfirmationRefreshReason
    ) {
        if case let .insufficientNativeFee(shortage) = failure {
            applyInsufficientNativeFee(shortage, stage: reason.logValue)
            resolvePendingConfirm()
            return
        }
        pendingSwap = nil
        guard let message = failure.confirmationUserMessage else { return }
        executionState = .preparationFailed(message)
        Log.multichainSwap.w(
            "swap preparation failed in confirmation",
            error: failure,
            extraInfo: confirmationLogInfo(additional: [
                "reason": reason.logValue,
            ])
        )
        onPreparationFailed(message)
    }

    func applyInsufficientNativeFee(_ shortage: MultichainNativeFeeShortage, stage: String) {
        guard !isRelayedFeeCovering else {
            return
        }
        nativeFeeShortageForFeeDisplay = shortage
        updateDisplay()
        Log.multichainSwap.w(
            "swap failed because native fee is insufficient",
            extraInfo: confirmationLogInfo(additional: [
                "assetId": shortage.asset.assetId,
                "stage": stage,
            ])
        )
    }
}

/// A swap the user started, until it is sent or abandoned.
private enum PendingSwap {
    /// Tapped before the plan that answers whether it can be confirmed, at the route then on screen.
    case awaitingPlan(tappedRoute: MultichainSwapRoute)
    case confirmed(ConfirmedSwap)
}

/// What a Swap tap opens when nothing can pay the fee.
private enum UnpaidFee {
    /// A battery refill could pay it, as could a deposit of the chain's coin.
    case battery(MultichainNativeFeeShortage)
    /// Only a deposit of the chain's coin could.
    case nativeCoin(MultichainNativeFeeShortage)
}

/// What the user agreed to when they confirmed.
private struct ConfirmedSwap {
    let input: MultichainSwapConfirmationInput
    let executionPlan: MultichainSwapExecutionPlan
    let feeMethod: MultichainSwapFeeMethod
}

private extension MultichainSwapConfirmationQuoteFailure {
    var message: String {
        switch self {
        case .quote(.unavailable):
            TKLocales.MultichainSwap.ProviderError.unknown
        case .quote(.pairUnavailable):
            TKLocales.NativeSwap.Quote.Rate.pairUnavailable
        case .quote(.walletScreened):
            TKLocales.MultichainSwap.ProviderError.walletScreened
        case .quote(.offline):
            TKLocales.MultichainSwap.Screen.Confirm.Error.networkError
        case .insufficientBalance:
            TKLocales.InsufficientFunds.insufficientBalance
        }
    }
}
