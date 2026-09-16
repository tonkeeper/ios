import Foundation
import KeeperCore
import TKLogging

@MainActor
final class MultichainSwapConfirmationRefreshModel {
    var onQuoteStateChange: ((MultichainSwapConfirmationQuoteState) -> Void)?
    var onExecutionPlanChange: ((MultichainSwapExecutionPlan?) -> Void)?
    var onPreparationFailure: ((MultichainSwapConfirmationRefreshReason, MultichainSwapExecutionFailure) -> Void)?
    var onQuoteRefreshFailed: ((MultichainSwapConfirmationRefreshReason, _ providerMessage: String?) -> Void)?
    var onRefreshCycleCompleted: (() -> Void)?

    private let wallet: Wallet
    private let quoteRefresher: MultichainSwapConfirmationQuoteRefresher
    private let executionService: MultichainSwapExecutionService
    private let routeRecovery: MultichainSwapRouteRecovery
    private let logInfoMaker: MultichainSwapConfirmationLogInfoMaker
    private var refreshTask: Task<Void, Never>?

    init(
        wallet: Wallet,
        quoteRefresher: MultichainSwapConfirmationQuoteRefresher,
        executionService: MultichainSwapExecutionService,
        routeRecovery: MultichainSwapRouteRecovery,
        logInfoMaker: MultichainSwapConfirmationLogInfoMaker
    ) {
        self.wallet = wallet
        self.quoteRefresher = quoteRefresher
        self.executionService = executionService
        self.routeRecovery = routeRecovery
        self.logInfoMaker = logInfoMaker
    }

    deinit {
        refreshTask?.cancel()
    }

    func loadInitialExecutionPlan(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int
    ) {
        refreshExecutionPlan(
            input: input,
            selectedSlippageBps: selectedSlippageBps,
            reason: .initial
        )
    }

    func refreshExecutionPlan(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        reason: MultichainSwapConfirmationRefreshReason
    ) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await loadExecutionPlan(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                reason: reason,
                routeRecoveryDelays: routeRecovery.delays
            )
        }
    }

    func refreshQuote(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        reason: MultichainSwapConfirmationRefreshReason
    ) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if !Task.isCancelled {
                    onRefreshCycleCompleted?()
                }
            }
            Log.multichainSwap.i(
                "confirmation quote refresh requested",
                extraInfo: logInfo(input: input, additional: ["reason": reason.logValue])
            )
            await performQuoteRefresh(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                reason: reason
            )
        }
    }

    func cancel() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

private extension MultichainSwapConfirmationRefreshModel {
    func performQuoteRefresh(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        reason: MultichainSwapConfirmationRefreshReason
    ) async {
        let refreshedQuoteState: MultichainSwapConfirmationQuoteState
        do {
            Log.multichainSwap.i(
                "confirmation quote refresh started",
                extraInfo: logInfo(
                    input: input,
                    additional: ["slippageBps": "\(selectedSlippageBps)"]
                )
            )
            refreshedQuoteState = try await quoteRefresher.refresh(
                input: input,
                selectedSlippageBps: selectedSlippageBps,
                wallet: wallet
            )
        } catch MultichainSwapConfirmationQuoteRefreshError.missingWalletAddress {
            guard !Task.isCancelled else { return }
            Log.multichainSwap.w(
                "confirmation quote refresh skipped due to missing wallet address",
                extraInfo: logInfo(input: input)
            )
            onQuoteRefreshFailed?(reason, nil)
            return
        } catch let MultichainSwapConfirmationQuoteRefreshError.noNonExpiredRoute(quote) {
            guard !Task.isCancelled else { return }
            Log.multichainSwap.w(
                "confirmation quote refresh completed without non-expired route",
                extraInfo: logInfo(
                    input: input,
                    additional: [
                        "quoteId": quote.quoteId,
                        "routeCount": "\(quote.routes.count)",
                        "offeredRoutes": quote.offeredRoutesLogDescription,
                        "providerErrors": quote.providerErrorsLogDescription,
                    ]
                )
            )
            let providerMessage = quote.routes.isEmpty ? quote.providerErrorMessage : nil
            onQuoteRefreshFailed?(reason, providerMessage)
            return
        } catch {
            guard !Task.isCancelled else { return }
            Log.multichainSwap.w(
                "confirmation quote refresh failed",
                error: error,
                extraInfo: logInfo(input: input)
            )
            onQuoteRefreshFailed?(reason, nil)
            return
        }

        guard !Task.isCancelled else { return }
        let updatedInput = MultichainSwapConfirmationInput(
            userInput: input.userInput,
            quoteState: refreshedQuoteState
        )
        onQuoteStateChange?(refreshedQuoteState)
        await loadExecutionPlan(
            input: updatedInput,
            selectedSlippageBps: selectedSlippageBps,
            reason: reason,
            routeRecoveryDelays: []
        )
        guard !Task.isCancelled else { return }
        Log.multichainSwap.i(
            "confirmation quote refresh completed",
            extraInfo: logInfo(
                input: updatedInput,
                additional: [
                    "quoteId": refreshedQuoteState.quote.quoteId,
                    "slippageBps": "\(selectedSlippageBps)",
                ]
            )
        )
    }

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
            let executionPlan = try await executionService.prepareExecutionPlan(
                wallet: wallet,
                sourceAsset: input.userInput.sendAsset,
                destinationAsset: input.userInput.receiveAsset,
                route: input.quoteState.route
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
                wallet: wallet
            )
        } catch {
            guard !Task.isCancelled else { return }
            Log.multichainSwap.w(
                "fresh route request failed",
                error: error,
                extraInfo: logInfo(input: input)
            )
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
        onRefreshCycleCompleted?()
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
