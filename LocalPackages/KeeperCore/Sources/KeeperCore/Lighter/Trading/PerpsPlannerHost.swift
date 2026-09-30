import ChainKit
import Foundation
import TKPerpsAPI

/// One market read, before any intent exists: the position an intent is built
/// from lives here, so nothing has to invent a probe intent to load it.
struct PerpsMarketContext {
    let walletId: String
    let scope: PerpsScope
    let rules: PerpsMarketRules
    let accountSnapshot: PerpetualAccountSnapshot
    let marketSnapshot: PerpetualMarketSnapshot?
    let symbol: String?
    let leverage: Double?
    let limitOrders: [PerpsLimitOrderSummary]
    let mark: PerpsMarkPrice?
    let nowUnixMs: Int64
}

struct PerpsPlannedTrade {
    let intent: PerpsTradeIntent
    let context: PerpsMarketContext
    let marketSnapshot: PerpetualMarketSnapshot?
    let plan: PerpetualOperation
}

final class PerpsPlannerHost {
    private static let maxFreshReads = 10
    private static let maxDepthReads = 4
    private static let maxIterations = 32

    private let api: PerpsAPI
    private let nonceCoordinator: PerpsNonceCoordinator
    private let freshReadDelayNanoseconds: UInt64
    private let mediator = LighterPerpsMediator()

    init(
        api: PerpsAPI,
        nonceCoordinator: PerpsNonceCoordinator = PerpsNonceCoordinator(),
        freshReadDelayNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.api = api
        self.nonceCoordinator = nonceCoordinator
        self.freshReadDelayNanoseconds = freshReadDelayNanoseconds
    }

    func signingKey(privateKeyHex: String, accountIndex: Int64, apiKeyIndex: Int32, chainId: Int32) throws -> PerpsSigningKey {
        try perpsValue(
            mediator.signingKey(privateKeyHex: privateKeyHex, accountIndex: accountIndex, apiKeyIndex: apiKeyIndex, chainId: chainId)
        )
    }

    func context(
        walletId: String,
        marketId: Int64,
        scope: PerpsScope,
        environment: String,
        liveMark: Double?
    ) async throws -> PerpsMarketContext {
        let now = PerpsPlannerMapping.nowUnixMs()
        let screen = try await api.tradingScreen(walletId: walletId, marketId: marketId)
        guard let market = screen.market else {
            throw PerpsTradingError.validation("trading screen has no market")
        }
        let rules = try PerpsPlannerMapping.rules(
            market: market,
            environment: environment,
            receivedAtUnixMs: now
        )
        let resting = try PerpsPlannerMapping.restingOrders(screen.open_orders, rules: rules)
        let tradingContext = try PerpsPlannerMapping.context(
            scope: scope,
            marketId: marketId,
            screen: screen,
            rules: rules,
            receivedAtUnixMs: now,
            restingOrders: resting
        )
        let mark = try PerpsPlannerMapping.markPrice(
            market.mark_price,
            live: liveMark,
            decimals: rules.scale.priceDecimals,
            nowUnixMs: now
        )
        return PerpsMarketContext(
            walletId: walletId,
            scope: scope,
            rules: rules,
            accountSnapshot: tradingContext,
            marketSnapshot: nil,
            symbol: market.symbol,
            leverage: screen.position?.value1.leverage.map(Double.init),
            limitOrders: PerpsBackendMapping.ordersVisible(screen.flags)
                ? PerpsBackendMapping.limitOrders(screen.open_orders) : [],
            mark: mark,
            nowUnixMs: now
        )
    }

    func plan(intent: PerpsTradeIntent, context: PerpsMarketContext) async throws -> PerpsPlannedTrade {
        let need = PerpsPlannerMapping.snapshotNeed(intent: intent, context: context)
        var coverage = need.coverageQuote
        for _ in 0 ..< Self.maxDepthReads {
            let snapshot = try await marketSnapshot(for: intent, context: context, coverageQuote: coverage)
            do {
                let plan = try prepare(intent: intent, context: context, marketSnapshot: snapshot)
                return PerpsPlannedTrade(
                    intent: intent,
                    context: context.withMarketSnapshot(snapshot),
                    marketSnapshot: snapshot,
                    plan: plan
                )
            } catch let error
                where perpsTradeException(from: error)?.kind === PerpsTradeError.needsmoredepth
                && snapshot?.book?.truncatedAtCoverage == true
                && coverage <= Int64.max / 2
            {
                coverage *= 2
            }
        }
        throw PerpsTradingError.insufficientLiquidity
    }

    func prepare(
        intent: PerpsTradeIntent,
        context: PerpsMarketContext,
        marketSnapshot: PerpetualMarketSnapshot?,
        applied: [PerpsAppliedPrerequisite] = []
    ) throws -> PerpetualOperation {
        try perpsValue(mediator.prepare(
            request: PerpsPrepareRequest(
                intent: intent,
                rules: context.rules,
                accountSnapshot: context.accountSnapshot,
                marketSnapshot: marketSnapshot,
                planId: UUID().uuidString,
                nowUnixMs: PerpsPlannerMapping.nowUnixMs(),
                freshnessPolicy: PerpsPlannerMapping.freshnessPolicy(),
                appliedPrerequisites: applied
            )
        ))
    }

    func execute(
        planned: PerpsPlannedTrade,
        signingKey: PerpsSigningKey,
        onSigned: @escaping (PerpsSignedStep) async throws -> Void
    ) async throws {
        let execution = PerpsExecutionRelay(
            api: api,
            nonceCoordinator: nonceCoordinator,
            persist: onSigned
        )
        try await execute(planned: planned, signingKey: signingKey, execution: execution)
    }

    func execute(
        planned: PerpsPlannedTrade,
        signingKey: PerpsSigningKey,
        execution: PerpsExecutionDelegate
    ) async throws {
        let intent = planned.intent
        var applied = [PerpsAppliedPrerequisite]()
        var currentPlan = planned.plan
        var currentContext = planned.context
        var completedStepIds = Set<String>()
        var freshReads = 0
        var iterations = 0
        while let step = currentPlan.steps.first(where: { !completedStepIds.contains($0.stepId) }) {
            iterations += 1
            guard iterations <= Self.maxIterations else {
                throw PerpsTradingError.operationInProgress
            }
            switch verdict(plan: currentPlan, stepId: step.stepId, context: currentContext, applied: applied) {
            case let .approved(approval):
                let now = PerpsPlannerMapping.nowUnixMs()
                let expiry = min(
                    now + LighterConstants.shared.DefaultExpireTimeMillis,
                    LighterConstants.shared.MaxTimestamp
                )
                do {
                    _ = try await bridgeKotlin { completion in
                        self.mediator.executeStep(
                            plan: currentPlan,
                            stepId: step.stepId,
                            currentContext: self.signingContext(
                                context: currentContext,
                                applied: applied
                            ),
                            approval: approval,
                            signingKey: signingKey,
                            execution: execution,
                            attemptId: UUID().uuidString,
                            nowUnixMs: now,
                            transactionExpiryUnixMs: expiry,
                            completionHandler: completion
                        )
                    }
                } catch {
                    throw PerpsTradingErrorMapper.map(error)
                }
                applied.append(prerequisite(for: step, plan: currentPlan, intent: intent, context: currentContext))
                completedStepIds.insert(step.stepId)
            case .alreadySettled:
                completedStepIds.insert(step.stepId)
            case .requiresFreshContext:
                guard freshReads < Self.maxFreshReads else {
                    throw PerpsTradingError.operationInProgress
                }
                freshReads += 1
                try await Task.sleep(nanoseconds: freshReadDelayNanoseconds)
                currentContext = try await refresh(context: currentContext)
            case let .requiresPrepare(reason):
                guard applied.isEmpty, Self.replans(on: reason) else {
                    throw PerpsTradingError.stalePreparedTransaction
                }
                let replanned = try await plan(intent: intent, context: refresh(context: currentContext))
                currentPlan = replanned.plan
                currentContext = replanned.context
            case .requiresAppliedStep:
                throw PerpsTradingError.operationInProgress
            }
        }
    }
}

extension PerpsMarketContext {
    func withMarketSnapshot(_ snapshot: PerpetualMarketSnapshot?) -> PerpsMarketContext {
        PerpsMarketContext(
            walletId: walletId,
            scope: scope,
            rules: rules,
            accountSnapshot: accountSnapshot,
            marketSnapshot: snapshot,
            symbol: symbol,
            leverage: leverage,
            limitOrders: limitOrders,
            mark: mark,
            nowUnixMs: nowUnixMs
        )
    }
}

extension PerpsPlannerHost {
    enum Verdict {
        case approved(PerpetualApproval)
        case alreadySettled
        case requiresFreshContext
        case requiresPrepare(PerpsTradeError)
        case requiresAppliedStep
    }

    static func replans(on reason: PerpsTradeError) -> Bool {
        reason === PerpsTradeError.staleinput
            || reason === PerpsTradeError.planexpired
            || reason === PerpsTradeError.unusablesnapshot
            || reason === PerpsTradeError.invalidrules
    }

    func verdict(
        plan: PerpetualOperation,
        stepId: String,
        context: PerpsMarketContext,
        applied: [PerpsAppliedPrerequisite]
    ) -> Verdict {
        let validation = mediator.validateForSigning(
            plan: plan,
            stepId: stepId,
            currentContext: signingContext(context: context, applied: applied),
            nowUnixMs: PerpsPlannerMapping.nowUnixMs()
        )
        if let approved = validation as? PerpetualValidation.Approved {
            return .approved(approved.approval)
        }
        if validation is PerpetualValidation.AlreadySettled {
            return .alreadySettled
        }
        if validation is PerpetualValidation.RequiresFreshContext {
            return .requiresFreshContext
        }
        if let prepare = validation as? PerpetualValidation.RequiresPrepare {
            return .requiresPrepare(prepare.reason)
        }
        return .requiresAppliedStep
    }

    func signingContext(
        context: PerpsMarketContext,
        applied: [PerpsAppliedPrerequisite]
    ) -> PerpsSigningValidationContext {
        PerpsSigningValidationContext(
            rules: context.rules,
            accountSnapshot: context.accountSnapshot,
            appliedPrerequisites: applied,
            freshnessPolicy: PerpsPlannerMapping.freshnessPolicy(),
            marketSnapshot: context.marketSnapshot
        )
    }

    func marketSnapshot(
        for intent: PerpsTradeIntent,
        context: PerpsMarketContext,
        coverageQuote: Int64? = nil
    ) async throws -> PerpetualMarketSnapshot? {
        let need = PerpsPlannerMapping.snapshotNeed(intent: intent, context: context)
        guard let side = need.side else {
            guard need.includeMark else { return nil }
            return PerpsPlannerMapping.markSnapshot(
                marketId: context.rules.marketId,
                environment: context.scope.environment,
                mark: context.mark,
                receivedAtUnixMs: PerpsPlannerMapping.nowUnixMs()
            )
        }
        let coverage = coverageQuote ?? need.coverageQuote
        let book = try await api.truncatedOrderBook(
            walletId: context.walletId,
            marketId: context.rules.marketId,
            side: PerpsPlannerMapping.bookSide(side),
            feeRate: PerpsScaled.feeRate(takerPpm: context.rules.takerFeePpm),
            notional: PerpsScaled.decimalString(coverage, decimals: context.rules.scale.quoteDecimals)
        )
        return try PerpsPlannerMapping.marketSnapshot(
            side: side,
            coverageQuote: coverage,
            book: book,
            mark: context.mark,
            marketId: context.rules.marketId,
            rules: context.rules,
            environment: context.scope.environment,
            receivedAtUnixMs: PerpsPlannerMapping.nowUnixMs()
        )
    }

    func refresh(context: PerpsMarketContext) async throws -> PerpsMarketContext {
        try await self.context(
            walletId: context.walletId,
            marketId: context.rules.marketId,
            scope: context.scope,
            environment: context.scope.environment,
            liveMark: nil
        )
    }

    func prerequisite(
        for step: PerpetualStep,
        plan: PerpetualOperation,
        intent: PerpsTradeIntent,
        context: PerpsMarketContext
    ) -> PerpsAppliedPrerequisite {
        if step.stepId == "leverage" {
            let bps: Int32
            if let open = intent as? PerpsTradeIntent.Open {
                bps = open.initialMarginBps
            } else if let add = intent as? PerpsTradeIntent.Add {
                bps = add.initialMarginBps
            } else if let known = context.accountSnapshot.marginSettings as? PerpsMarginSettings.Known {
                bps = known.initialMarginBps
            } else {
                bps = context.rules.minInitialMarginBps
            }
            return PerpsAppliedPrerequisite.LeverageApplied(
                operationId: plan.operationId,
                scope: context.scope,
                initialMarginBps: bps,
                marginMode: LighterConstants.shared.IsolatedMargin
            )
        }
        return PerpsAppliedPrerequisite.StepApplied(
            operationId: plan.operationId,
            scope: context.scope,
            stepId: step.stepId,
            planDigest: plan.planDigest
        )
    }
}
