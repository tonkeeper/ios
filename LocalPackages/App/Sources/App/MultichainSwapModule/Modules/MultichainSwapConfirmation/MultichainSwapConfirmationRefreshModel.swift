import Foundation
import KeeperCore
import TKLogging

@MainActor
final class MultichainSwapConfirmationRefreshModel {
    /// A fresh route fetched after the one being prepared went stale.
    var onQuoteStateChange: ((MultichainSwapConfirmationQuoteState) -> Void)?
    var onExecutionPlanChange: ((MultichainSwapExecutionPlan?) -> Void)?
    var onPreparationFailure: ((MultichainSwapConfirmationRefreshReason, MultichainSwapExecutionFailure) -> Void)?

    private let swapWallet: MultichainSwapWallet
    private let quoteRefresher: MultichainSwapConfirmationQuoteRefresher
    private let planProvider: MultichainSwapPlanProvider
    private let routeRecovery: MultichainSwapRouteRecovery
    private let logInfoMaker: MultichainSwapConfirmationLogInfoMaker
    private(set) var refreshTask: Task<Void, Never>?

    init(
        swapWallet: MultichainSwapWallet,
        quoteRefresher: MultichainSwapConfirmationQuoteRefresher,
        planProvider: MultichainSwapPlanProvider,
        routeRecovery: MultichainSwapRouteRecovery,
        logInfoMaker: MultichainSwapConfirmationLogInfoMaker
    ) {
        self.swapWallet = swapWallet
        self.quoteRefresher = quoteRefresher
        self.planProvider = planProvider
        self.routeRecovery = routeRecovery
        self.logInfoMaker = logInfoMaker
    }

    deinit {
        refreshTask?.cancel()
    }

    var isPreparing: Bool {
        refreshTask != nil
    }

    func refreshExecutionPlan(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        reason: MultichainSwapConfirmationRefreshReason,
        recoversStaleRoute: Bool = true
    ) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await loadExecutionPlan(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                reason: reason,
                routeRecoveryDelays: recoversStaleRoute ? routeRecovery.delays : []
            )
            if !Task.isCancelled {
                refreshTask = nil
            }
        }
    }

    func cancel() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

private extension MultichainSwapConfirmationRefreshModel {
    func loadExecutionPlan(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        reason: MultichainSwapConfirmationRefreshReason,
        routeRecoveryDelays: [TimeInterval]
    ) async {
        Log.multichainSwap.i(
            "confirmation swap preparation started",
            extraInfo: logInfo(input: input)
        )
        do {
            let executionPlan = try await planProvider.plan(
                sourceAsset: input.userInput.sendAsset,
                destinationAsset: input.userInput.receiveAsset,
                route: input.quoteState.route,
                reusingPrepared: reason.reusesPreparedPlan
            )
            guard !Task.isCancelled else { return }
            onExecutionPlanChange?(executionPlan)
            Log.multichainSwap.i(
                "confirmation swap preparation completed",
                extraInfo: logInfo(
                    input: input,
                    additional: [
                        "feeAssets": MultichainSwapConfirmationLogInfoMaker.feeAssetsLogDescription(executionPlan.networkFees),
                    ]
                )
            )
        } catch {
            guard !Task.isCancelled else { return }
            Log.multichainSwap.w(
                "confirmation swap preparation failed",
                error: error,
                extraInfo: logInfo(input: input)
            )
            guard error.requiresFreshRoute else {
                onExecutionPlanChange?(nil)
                onPreparationFailure?(reason, error)
                return
            }
            await advanceRouteRecovery(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                reason: reason,
                failure: error,
                delays: routeRecoveryDelays
            )
        }
    }

    /// Takes the next rung of the backoff ladder, or reports the stale-route failure once the
    /// ladder is spent.
    func advanceRouteRecovery(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        reason: MultichainSwapConfirmationRefreshReason,
        failure: MultichainSwapExecutionFailure,
        delays: [TimeInterval]
    ) async {
        guard let delay = delays.first else {
            Log.multichainSwap.w(
                "route recovery gave up after the backoff ladder",
                error: failure,
                extraInfo: logInfo(
                    input: input,
                    additional: ["attempts": "\(routeRecovery.delays.count)"]
                )
            )
            onExecutionPlanChange?(nil)
            onPreparationFailure?(reason, failure)
            return
        }
        await recoverStaleRoute(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: reason,
            failure: failure,
            delay: delay,
            remainingDelays: Array(delays.dropFirst())
        )
    }

    func recoverStaleRoute(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        reason: MultichainSwapConfirmationRefreshReason,
        failure: MultichainSwapExecutionFailure,
        delay: TimeInterval,
        remainingDelays: [TimeInterval]
    ) async {
        Log.multichainSwap.i(
            "confirmation swap preparation requests a fresh route",
            extraInfo: logInfo(
                input: input,
                additional: [
                    "failure": failure.logDescription,
                    "delay": "\(delay)",
                    "rungsLeft": "\(remainingDelays.count)",
                ]
            )
        )
        do {
            try await routeRecovery.sleep(delay)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        let refreshedQuoteState: MultichainSwapConfirmationQuoteState
        do {
            refreshedQuoteState = try await quoteRefresher.refresh(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                swapWallet: swapWallet
            )
        } catch {
            guard !Task.isCancelled else { return }
            Log.multichainSwap.w(
                "fresh route request failed",
                error: error,
                extraInfo: logInfo(input: input)
            )
            if let terminalFailure = (error as? MultichainSwapConfirmationQuoteRefreshError)?.terminalFailure {
                onExecutionPlanChange?(nil)
                onPreparationFailure?(reason, terminalFailure)
                return
            }
            await advanceRouteRecovery(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                reason: reason,
                failure: failure,
                delays: remainingDelays
            )
            return
        }
        guard !Task.isCancelled else { return }
        onQuoteStateChange?(refreshedQuoteState)
        await loadExecutionPlan(
            input: MultichainSwapConfirmationInput(
                userInput: input.userInput,
                quoteState: refreshedQuoteState
            ),
            selectedSlippageBps: selectedSlippageBps,
            reason: reason,
            routeRecoveryDelays: remainingDelays
        )
    }

    func logInfo(
        input: MultichainSwapConfirmationInput,
        additional: [String: String] = [:]
    ) -> [String: String] {
        logInfoMaker.make(input: input, additional: additional)
    }
}
