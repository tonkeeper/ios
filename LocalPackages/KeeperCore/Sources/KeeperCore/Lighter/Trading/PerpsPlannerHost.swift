import ChainKit
import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

/// One market read, before any intent exists: the position an intent is built
/// from lives here, so nothing has to invent a probe intent to load it.
struct PerpsReviewInputs {
    let context: PerpsMarketContext
    let marketSnapshot: PerpetualMarketSnapshot?
    let symbol: String
}

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
    private let reissueReadOnlyToken: @Sendable () async -> Bool
    private let serverClock: PerpsServerClock
    private let mediator = LighterPerpsMediator()

    init(
        api: PerpsAPI,
        nonceCoordinator: PerpsNonceCoordinator,
        freshReadDelayNanoseconds: UInt64 = 1_000_000_000,
        serverClock: PerpsServerClock = .shared,
        reissueReadOnlyToken: @escaping @Sendable () async -> Bool = { false }
    ) {
        self.api = api
        self.nonceCoordinator = nonceCoordinator
        self.freshReadDelayNanoseconds = freshReadDelayNanoseconds
        self.serverClock = serverClock
        self.reissueReadOnlyToken = reissueReadOnlyToken
    }

    func signingKey(privateKeyHex: String, accountIndex: Int64, chainId: Int32) throws -> PerpsSigningKey {
        try perpsValue(
            mediator.signingKey(privateKeyHex: privateKeyHex, accountIndex: accountIndex, chainId: chainId)
        )
    }

    func context(
        walletId: String,
        marketId: Int64,
        scope: PerpsScope,
        environment: String,
        liveMark: Double?,
        openInitialMarginBps: Int32? = nil
    ) async throws -> PerpsMarketContext {
        let now = PerpsPlannerMapping.nowUnixMs()
        // Neither read depends on the other, and this runs on every quote — serial would
        // put a second round trip in front of every price the user sees.
        async let screenRead = PerpsAPIError.reissuingReadOnlyToken(reissueReadOnlyToken) {
            try await api.tradingScreen(walletId: walletId, marketId: marketId)
        }
        async let integratorRead = api.integrator(walletId: walletId)
        let screen = try await screenRead
        if let serverOffset = serverClock.serverOffsetMs, PerpsServerClock.isDeviceClockSkewed(serverOffsetMs: serverOffset) {
            Log.perps.w("device clock skew market=\(marketId) serverOffset=\(serverOffset)")
            throw PerpsTradingError.deviceClockSkew
        }
        guard let market = screen.market else {
            throw PerpsTradingError.validation("trading screen has no market")
        }
        let integrator = try await integratorRead
        let rules = try PerpsPlannerMapping.rules(
            market: market,
            environment: environment,
            receivedAtUnixMs: now,
            integrator: integrator
        )
        var resting = try PerpsPlannerMapping.restingOrders(screen.open_orders, rules: rules)
        var ordersKnown = PerpsBackendMapping.ordersReadable(screen)
        if !ordersKnown {
            let detail = try? await api.getOpenPosition(
                walletId: walletId,
                id: PerpsPlannerMapping.tkPositionId(marketId: marketId)
            )
            if let detail, detail.auto_close_known == true {
                resting = try PerpsPlannerMapping.restingOrders(
                    autoClose: detail.auto_close?.value1,
                    positionSide: detail.position?.side,
                    rules: rules
                )
                ordersKnown = true
            }
        }
        let tradingContext = try PerpsPlannerMapping.context(
            scope: scope,
            marketId: marketId,
            screen: screen,
            rules: rules,
            receivedAtUnixMs: now,
            restingOrders: resting,
            ordersKnown: ordersKnown,
            openInitialMarginBps: openInitialMarginBps
        )
        if !ordersKnown {
            Log.perps.w("planner context without readable orders market=\(marketId) cancel_enabled=\(screen.flags?.cancel_enabled.map { "\($0)" } ?? "nil") position=\(screen.position == nil ? "none" : "open")")
        }
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
            limitOrders: PerpsBackendMapping.limitOrders(screen.open_orders),
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
                Log.perps.i("plan \(intent) → \(plan.review) steps=\(plan.steps.map(\.stepId)) validUntil=\(plan.validUntilUnixMs) coverage=\(coverage)")
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
                Log.perps.i("plan needs more depth market=\(context.rules.marketId) coverage=\(coverage)→\(coverage * 2)")
                coverage *= 2
            }
        }
        Log.perps.w("plan out of depth market=\(context.rules.marketId) coverage=\(coverage)")
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
                throw Self.unfinished(applied)
            }
            switch verdict(plan: currentPlan, stepId: step.stepId, context: currentContext, applied: applied) {
            case let .approved(approval):
                let now = PerpsPlannerMapping.nowUnixMs()
                let expiry = min(
                    serverClock.serverNowUnixMs(deviceNowUnixMs: now) + LighterConstants.shared.DefaultExpireTimeMillis,
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
                Log.perps.i("step \(step.stepId) already settled operation=\(currentPlan.operationId)")
                completedStepIds.insert(step.stepId)
            case .requiresFreshContext:
                guard freshReads < Self.maxFreshReads else {
                    throw Self.unfinished(applied)
                }
                freshReads += 1
                Log.perps.i("step \(step.stepId) waits for fresh context operation=\(currentPlan.operationId) read=\(freshReads)")
                try await Task.sleep(nanoseconds: freshReadDelayNanoseconds)
                currentContext = try await refresh(context: currentContext)
            case let .requiresPrepare(reason):
                Log.perps.i("step \(step.stepId) needs a replan operation=\(currentPlan.operationId) reason=\(reason) applied=\(applied.count)")
                guard applied.isEmpty, Self.replans(on: reason) else {
                    throw PerpsTradingError.stalePreparedTransaction
                }
                let replanned = try await plan(intent: intent, context: refresh(context: currentContext))
                currentPlan = replanned.plan
                currentContext = replanned.context
            case .requiresAppliedStep:
                throw Self.unfinished(applied)
            }
        }
    }

    private static func unfinished(_ applied: [PerpsAppliedPrerequisite]) -> PerpsTradingError {
        applied.isEmpty ? .stalePreparedTransaction : .operationInProgress
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
        let notional = PerpsScaled.decimalString(coverage, decimals: context.rules.scale.quoteDecimals)
        let book = try await api.truncatedOrderBook(
            walletId: context.walletId,
            marketId: context.rules.marketId,
            side: PerpsPlannerMapping.bookSide(side),
            feeRate: PerpsScaled.feeRate(takerPpm: PerpsPlannerMapping.effectiveTakerFeePpm(intent: intent, rules: context.rules)),
            notional: notional
        )
        let now = PerpsPlannerMapping.nowUnixMs()
        let bookUpdatedAt = Int64(book.updated_at.timeIntervalSince1970 * 1000)
        if bookUpdatedAt - now > PerpsPlannerMapping.freshnessPolicy().maxFutureSkewUnixMs {
            Log.perps.w("device clock skew market=\(context.rules.marketId) bookUpdatedAt=\(bookUpdatedAt) now=\(now)")
            throw PerpsTradingError.deviceClockSkew
        }
        let levels = (side === PerpsSide.short_ ? book.bids : book.asks) ?? []
        Log.perps.i("book market=\(context.rules.marketId) side=\(PerpsPlannerMapping.bookSide(side)) notional=\(notional) levels=\(levels.count) truncated=\(book.truncated) updatedAt=\(book.updated_at) mark=\(context.mark.map { "\($0.price)@\($0.observedAtUnixMs)" } ?? "nil") top=\(levels.prefix(5).map { "\($0.price)x\($0.size)" })")
        return try PerpsPlannerMapping.marketSnapshot(
            side: side,
            coverageQuote: coverage,
            book: book,
            mark: context.mark,
            marketId: context.rules.marketId,
            rules: context.rules,
            environment: context.scope.environment,
            receivedAtUnixMs: now
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
