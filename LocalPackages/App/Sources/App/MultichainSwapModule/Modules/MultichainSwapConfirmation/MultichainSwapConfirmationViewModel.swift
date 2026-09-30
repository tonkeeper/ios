import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import UIKit

@MainActor
final class MultichainSwapConfirmationViewModel: ObservableObject {
    @Published private(set) var display: MultichainSwapConfirmationDisplay
    @Published private(set) var executionState: MultichainSwapConfirmationExecutionState = .idle
    @Published private(set) var isUnlimitedApprovalEnabled = false
    @Published private(set) var selectedSlippageBps: Int
    @Published private(set) var sliderResetToken: Int = 0
    @Published private(set) var circularProgressRestartToken: Int = 0

    let confirmationRefreshDuration: TimeInterval = 45
    private(set) var slippageOptions: [Int]

    var onRequestSlippageSelection: ((UIView) -> Void)?

    private let wallet: Wallet
    private var input: MultichainSwapConfirmationInput
    private let amountFormatter: AmountFormatter
    private let priceImpactResolver: MultichainSwapConfirmationPriceImpactResolver
    private let displayMaker: MultichainSwapConfirmationDisplayMaker
    private let refreshModel: MultichainSwapConfirmationRefreshModel
    private let executor: MultichainSwapConfirmationExecutor
    private let logInfoMaker: MultichainSwapConfirmationLogInfoMaker
    private let onBack: () -> Void
    private let onClose: () -> Void
    private let onSwipeConfirm: () -> Void
    private let onExecutionCompleted: (MultichainSwapConfirmationInput, MultichainSwapFeeMethod) -> Void
    private let onExecutionFailed: (String) -> Void
    private let onQuoteProviderError: (String) -> Void
    private let onInsufficientNativeFee: (MultichainNativeFeeShortage) -> Void
    private let onFeeCalculationStarted: (MultichainSwapConfirmationRefreshReason) -> Void
    private let onOpenFeePicker: (NetworkFeePickerPresentation) -> Void
    private let onRefillBattery: (@escaping () -> Void) -> Void
    private let onBatteryFeeShortage: (MultichainNativeFeeShortage) -> Void
    private let onDepositNativeFee: (MultichainAssetDetails) -> Void
    private var pickedFeeMethod: MultichainSwapFeeMethod?
    /// What the in-flight send is paying with, held until its outcome is known: a failure has to
    /// judge a retry against the method that was actually sent, not the one on screen by then.
    private var sentFeeMethod: MultichainSwapFeeMethod?
    /// What the last plan that priced this swap would have paid with, or `nil` if none of its methods
    /// could pay. Outlives the plan so a failed refresh cannot flash a shortage the relayer covers.
    private var lastCoveringFeeMethod: MultichainSwapFeeMethod?
    private var isRetryUnsafe = false
    private var executionPlan: MultichainSwapExecutionPlan?
    private var nativeFeeShortageForFeeDisplay: MultichainNativeFeeShortage?
    private var slippageRollbackState: SlippageRollbackState?
    private var confirmedSwap: ConfirmedSwap?

    init(
        wallet: Wallet,
        confirmationInput: MultichainSwapConfirmationInput,
        amountFormatter: AmountFormatter,
        executionService: MultichainSwapExecutionService,
        multichainSwapService: MultichainSwapService,
        isSwapKitEnabled: Bool = false,
        slippageService: (any MultichainSwapSlippageService)? = nil,
        routeRecovery: MultichainSwapRouteRecovery = .default,
        onBack: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        onSwipeConfirm: @escaping () -> Void = {},
        onExecutionCompleted: @escaping (MultichainSwapConfirmationInput, MultichainSwapFeeMethod) -> Void = { _, _ in },
        onExecutionFailed: @escaping (String) -> Void = { _ in },
        onQuoteProviderError: @escaping (String) -> Void = { _ in },
        onInsufficientNativeFee: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onFeeCalculationStarted: @escaping (MultichainSwapConfirmationRefreshReason) -> Void = { _ in },
        onOpenFeePicker: @escaping (NetworkFeePickerPresentation) -> Void = { _ in },
        onRefillBattery: @escaping (@escaping () -> Void) -> Void = { _ in },
        onBatteryFeeShortage: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onDepositNativeFee: @escaping (MultichainAssetDetails) -> Void = { _ in }
    ) {
        self.wallet = wallet
        self.input = confirmationInput
        self.amountFormatter = amountFormatter
        let priceImpactResolver = MultichainSwapConfirmationPriceImpactResolver()
        let displayMaker = MultichainSwapConfirmationDisplayMaker(
            amountFormatter: amountFormatter
        )
        let logInfoMaker = MultichainSwapConfirmationLogInfoMaker(
            priceImpactResolver: priceImpactResolver
        )
        self.priceImpactResolver = priceImpactResolver
        self.displayMaker = displayMaker
        self.refreshModel = MultichainSwapConfirmationRefreshModel(
            wallet: wallet,
            quoteRefresher: MultichainSwapConfirmationQuoteRefresher(
                multichainSwapService: multichainSwapService,
                requestedAggregators: MultichainSwapQuoteRequest.requestedAggregators(
                    isSwapKitEnabled: isSwapKitEnabled
                )
            ),
            executionService: executionService,
            routeRecovery: routeRecovery,
            logInfoMaker: logInfoMaker
        )
        self.executor = MultichainSwapConfirmationExecutor(
            executionService: executionService
        )
        self.logInfoMaker = logInfoMaker
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
        let selectedSlippageBps = resolvedSlippageService.initialSelectedBps(
            route: confirmationInput.quoteState.route
        )
        self.selectedSlippageBps = selectedSlippageBps
        self.display = displayMaker.make(
            input: confirmationInput,
            networkFees: nil,
            selectedSlippageBps: selectedSlippageBps
        )
        self.onBack = onBack
        self.onClose = onClose
        self.onSwipeConfirm = onSwipeConfirm
        self.onExecutionCompleted = onExecutionCompleted
        self.onExecutionFailed = onExecutionFailed
        self.onQuoteProviderError = onQuoteProviderError
        self.onInsufficientNativeFee = onInsufficientNativeFee
        self.onFeeCalculationStarted = onFeeCalculationStarted
        self.onOpenFeePicker = onOpenFeePicker
        self.onRefillBattery = onRefillBattery
        self.onBatteryFeeShortage = onBatteryFeeShortage
        self.onDepositNativeFee = onDepositNativeFee
        refreshModel.onQuoteStateChange = { [weak self] quoteState in
            guard let self else { return }
            slippageRollbackState = nil
            input = MultichainSwapConfirmationInput(
                userInput: input.userInput,
                quoteState: quoteState
            )
            executionPlan = nil
            nativeFeeShortageForFeeDisplay = nil
            updateDisplay()
        }
        refreshModel.onExecutionPlanChange = { [weak self] executionPlan in
            guard let self else { return }
            self.executionPlan = executionPlan
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
            if executionPlan?.requiresApproval != true {
                isUnlimitedApprovalEnabled = false
            }
            updateDisplay()
            notifyBatteryFeeShortageIfNeeded()
        }
        refreshModel.onPreparationFailure = { [weak self] reason, failure in
            self?.applyPreparationFailure(failure, reason: reason)
        }
        refreshModel.onQuoteRefreshFailed = { [weak self] reason, providerMessage in
            self?.handleQuoteRefreshFailure(reason: reason, providerMessage: providerMessage)
        }
        refreshModel.onRefreshCycleCompleted = { [weak self] in
            self?.circularProgressRestartToken += 1
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

    var showsUnlimitedApprovalToggle: Bool {
        executionPlan?.requiresApproval == true
    }

    var canSelectSlippage: Bool {
        slippageOptions.count > 1 && executionState.isConfirmEnabled
    }

    var canChangeApprovalMode: Bool {
        showsUnlimitedApprovalToggle && executionState.isConfirmEnabled
    }

    var isConfirmEnabled: Bool {
        executionState.isConfirmEnabled
            && executionPlan != nil
            && !isRetryUnsafe
            && selectedFeeOption?.isInsufficient != true
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

    func openFeeMethodPicker() {
        let options = executionPlan?.feeOptions ?? []
        guard display.canPickFeeMethod, !options.isEmpty else {
            return
        }
        let selectedMethod = selectedFeeOption?.method
        // A swap prices each method at most once, so the method identifies its row: a position would
        // resolve against whichever list the picker was built from rather than what was tapped.
        let items = options.map { option in
            NetworkFeePickerItem(
                id: option.method.rawValue,
                leading: option.extraType.networkFeePickerLeading,
                text: .titled(
                    title: option.extraType.networkFeePickerTitle,
                    subtitle: option.feeValueText(amountFormatter: amountFormatter)
                ),
                isDisabled: option.isInsufficient,
                actionTitle: option.isInsufficient ? TKLocales.FeeMethodPicker.deposit : nil,
                isSelected: option.method == selectedMethod
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
                          let method = MultichainSwapFeeMethod(rawValue: item.id),
                          let option = options.first(where: { $0.method == method })
                    else {
                        return
                    }
                    selectFeeOption(option)
                }
            )
        )
    }

    func viewDidLoad() {
        onFeeCalculationStarted(.initial)
        refreshModel.loadInitialExecutionPlan(
            input: input,
            selectedSlippageBps: selectedSlippageBps
        )
    }

    func refreshFeeCalculationAfterDeposit() {
        guard executionState != .executing, executionState != .completed else {
            return
        }
        onFeeCalculationStarted(.feeDeposit)
        refreshModel.refreshExecutionPlan(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: .feeDeposit
        )
    }

    func back() {
        onBack()
    }

    func close() {
        onClose()
    }

    func confirmSwipe() {
        guard isConfirmEnabled else {
            Log.multichainSwap.i(
                "confirmation swipe ignored while execution plan is not ready",
                extraInfo: confirmationLogInfo()
            )
            sliderResetToken += 1
            return
        }
        guard let executionPlan else {
            sliderResetToken += 1
            return
        }
        // A price impact warning stands between the swipe and the send, and the quote keeps
        // refreshing behind it. Pin what the row showed: the swap is sent with the plan and the fee
        // method the user agreed to, or not at all.
        confirmedSwap = ConfirmedSwap(
            input: input,
            executionPlan: executionPlan,
            feeMethod: selectedFeeMethod,
            isUnlimitedApprovalEnabled: isUnlimitedApprovalEnabled
        )
        refreshModel.cancel()
        Log.multichainSwap.i(
            "confirmation swipe accepted",
            extraInfo: confirmationLogInfo(
                additional: [
                    "requiresPriceImpactWarning": requiresPriceImpactWarning ? "true" : "false",
                    "feeMethod": "\(selectedFeeMethod)",
                ]
            )
        )
        onSwipeConfirm()
    }

    func notifyCircularProgressCompleted() {
        guard confirmedSwap == nil else {
            return
        }
        switch executionState {
        case .executing, .completed:
            return
        case .idle, .preparationFailed, .executionFailed:
            break
        }
        onFeeCalculationStarted(.timer)
        refreshModel.refreshQuote(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: .timer
        )
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
        let rollbackState = slippageRollbackState ?? SlippageRollbackState(
            input: input,
            executionPlan: executionPlan,
            selectedSlippageBps: selectedSlippageBps
        )
        if bps == rollbackState.selectedSlippageBps {
            refreshModel.cancel()
            slippageRollbackState = nil
            input = rollbackState.input
            executionPlan = rollbackState.executionPlan
            selectedSlippageBps = rollbackState.selectedSlippageBps
            sliderResetToken += 1
            updateDisplay()
            return
        }
        slippageRollbackState = rollbackState
        selectedSlippageBps = bps
        executionPlan = nil
        nativeFeeShortageForFeeDisplay = nil
        sliderResetToken += 1
        updateDisplay()
        onFeeCalculationStarted(.slippageChanged)
        refreshModel.refreshQuote(
            input: input,
            selectedSlippageBps: bps,
            reason: .slippageChanged
        )
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

    func setUnlimitedApprovalEnabled(_ isEnabled: Bool) {
        guard canChangeApprovalMode else {
            Log.multichainSwap.i(
                "approval mode change ignored while confirmation is locked",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        isUnlimitedApprovalEnabled = isEnabled
    }

    /// Backing out of the confirmation releases what the swipe pinned. The pin also held the quote,
    /// so the cycle restarts here rather than a full period later: a freshly reset ring must not sit
    /// above a route that kept ageing while the warning was open.
    func resetConfirmSlider() {
        let wasConfirmed = confirmedSwap != nil
        confirmedSwap = nil
        sliderResetToken += 1
        guard wasConfirmed else {
            return
        }
        circularProgressRestartToken += 1
        onFeeCalculationStarted(.timer)
        refreshModel.refreshQuote(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: .timer
        )
    }

    func execute(
        passcodeProvider: @escaping () async -> String?
    ) {
        guard executionState != .executing else {
            Log.multichainSwap.i(
                "execution request ignored while already executing",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        guard let confirmed = confirmedSwap else {
            Log.multichainSwap.i(
                "execution skipped: no confirmed swap to send",
                extraInfo: confirmationLogInfo()
            )
            sliderResetToken += 1
            return
        }
        confirmedSwap = nil
        Log.multichainSwap.i(
            "execution requested from confirmation",
            extraInfo: confirmationLogInfo(
                additional: ["feeMethod": "\(confirmed.feeMethod)"]
            )
        )
        refreshModel.cancel()
        isRetryUnsafe = false
        sentFeeMethod = confirmed.feeMethod
        executionState = .executing
        Task { [weak self] in
            guard let self else { return }
            let result = await executor.execute(
                passcodeProvider: passcodeProvider,
                wallet: wallet,
                input: confirmed.input,
                executionPlan: confirmed.executionPlan,
                isUnlimitedApprovalEnabled: confirmed.isUnlimitedApprovalEnabled,
                feeMethod: confirmed.feeMethod
            )
            switch result {
            case let .success(result):
                self.applyExecutionResult(result, confirmed: confirmed)
            case let .failure(failure):
                self.applyExecutionFailure(failure)
            }
        }
    }
}

private extension MultichainSwapConfirmationViewModel {
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

    /// The fee row can only say the chain's coin is short. When a relayer could pay instead, the
    /// screen has to name that way out, so the same guard that shows the deposit popup shows this one.
    func notifyBatteryFeeShortageIfNeeded() {
        guard let feeOptions = executionPlan?.feeOptions,
              !feeOptions.contains(where: { !$0.isInsufficient }),
              feeOptions.contains(where: { $0.method.isBattery }),
              let nativeOption = feeOptions.first(where: { $0.method == .native }),
              case let .native(fees, _) = nativeOption.cost,
              let nativeFee = fees.first
        else {
            return
        }
        onBatteryFeeShortage(
            MultichainNativeFeeShortage(
                asset: nativeFee.asset,
                requiredAmount: nativeFee.fee
            )
        )
    }

    func requestFeeRefill(for option: MultichainSwapFeeOption) {
        guard let asset = option.depositAsset else {
            onRefillBattery { [weak self] in
                self?.refreshFeeCalculationAfterDeposit()
            }
            return
        }
        onDepositNativeFee(asset)
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
        sentFeeMethod = nil
        Log.multichainSwap.i(
            "execution completed in confirmation",
            extraInfo: confirmationLogInfo(additional: ["txHash": result.txHash])
        )
        onExecutionCompleted(confirmed.input, confirmed.feeMethod)
    }

    func applyExecutionFailure(_ failure: MultichainSwapExecutionFailure) {
        let sentMethod = sentFeeMethod
        sentFeeMethod = nil
        circularProgressRestartToken += 1
        if case let .insufficientNativeFee(shortage) = failure {
            applyInsufficientNativeFee(shortage, stage: "execution")
            return
        }
        guard let message = failure.confirmationUserMessage else {
            executionState = .idle
            sliderResetToken += 1
            Log.multichainSwap.i(
                "execution canceled in confirmation",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        executionState = .executionFailed(message)
        // A relayed swap whose outcome is unknown must not be re-armed: signing again would send a
        // second, equally valid message once the first one lands and moves the seqno.
        isRetryUnsafe = sentMethod?.isRelayed == true && failure.isBroadcastOutcomeUnknown
        Log.multichainSwap.w(
            "execution failed in confirmation",
            error: failure,
            extraInfo: confirmationLogInfo(
                additional: ["retryUnsafe": isRetryUnsafe ? "true" : "false"]
            )
        )
        onExecutionFailed(message)
        guard !isRetryUnsafe else {
            return
        }
        sliderResetToken += 1
        onFeeCalculationStarted(.executionFailed)
        refreshModel.refreshQuote(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: .executionFailed
        )
    }

    func applyPreparationFailure(
        _ failure: MultichainSwapExecutionFailure,
        reason: MultichainSwapConfirmationRefreshReason
    ) {
        if case let .insufficientNativeFee(shortage) = failure {
            applyInsufficientNativeFee(shortage, stage: reason.logValue)
            return
        }
        guard let message = failure.confirmationUserMessage else { return }
        executionState = .preparationFailed(message)
        sliderResetToken += 1
        Log.multichainSwap.w(
            "swap preparation failed in confirmation",
            error: failure,
            extraInfo: confirmationLogInfo(additional: [
                "reason": reason.logValue,
            ])
        )
        // Silent on automatic (timer) refresh: the inline failed state is enough and
        // avoids re-toasting the same error every refresh cycle.
        guard reason.surfacesUserFacingError else { return }
        onExecutionFailed(message)
    }

    func applyInsufficientNativeFee(_ shortage: MultichainNativeFeeShortage, stage: String) {
        guard !isRelayedFeeCovering else {
            return
        }
        nativeFeeShortageForFeeDisplay = shortage
        executionState = .preparationFailed(TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance)
        sliderResetToken += 1
        updateDisplay()
        Log.multichainSwap.w(
            "swap failed because native fee is insufficient",
            extraInfo: confirmationLogInfo(additional: [
                "assetId": shortage.asset.assetId,
                "stage": stage,
            ])
        )
        onInsufficientNativeFee(shortage)
    }

    func handleQuoteRefreshFailure(
        reason: MultichainSwapConfirmationRefreshReason,
        providerMessage: String?
    ) {
        if reason == .slippageChanged {
            rollbackSlippageSelectionIfNeeded()
        }
        // Silent on automatic (timer) refresh; only user-initiated refreshes toast,
        // and only when the provider gave a concrete reason.
        guard reason.surfacesUserFacingError, let providerMessage else {
            return
        }
        onQuoteProviderError(providerMessage)
    }

    func rollbackSlippageSelectionIfNeeded() {
        guard let rollbackState = slippageRollbackState else { return }
        input = rollbackState.input
        executionPlan = rollbackState.executionPlan
        selectedSlippageBps = rollbackState.selectedSlippageBps
        slippageRollbackState = nil
        sliderResetToken += 1
        updateDisplay()
        Log.multichainSwap.i(
            "slippage selection reverted after quote refresh failed",
            extraInfo: confirmationLogInfo(
                additional: ["slippageBps": "\(rollbackState.selectedSlippageBps)"]
            )
        )
    }
}

/// What the user agreed to when the slider landed, held until the swap is sent or abandoned.
private struct ConfirmedSwap {
    let input: MultichainSwapConfirmationInput
    let executionPlan: MultichainSwapExecutionPlan
    let feeMethod: MultichainSwapFeeMethod
    let isUnlimitedApprovalEnabled: Bool
}

private struct SlippageRollbackState {
    let input: MultichainSwapConfirmationInput
    let executionPlan: MultichainSwapExecutionPlan?
    let selectedSlippageBps: Int
}
