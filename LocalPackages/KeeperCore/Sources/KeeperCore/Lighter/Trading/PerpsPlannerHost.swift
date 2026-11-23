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
    let venueTakerFeePpm: Int64?
    let accountSnapshot: PerpetualAccountSnapshot
    let marketSnapshot: PerpetualMarketSnapshot?
    let symbol: String?
    let leverage: Double?
    let entryPrice: Double?
    let limitOrders: [PerpsLimitOrderSummary]
    let mark: PerpsMarkPrice?
    let nowUnixMs: Int64
}

extension PerpsMarketContext {
    func displayedTakerFeePpm(_ kind: PerpsFeeKind) -> Int64 {
        PerpsPlannerMapping.displayedTakerFeePpm(kind, rules: rules, venueTakerFeePpm: venueTakerFeePpm)
    }
}

struct PerpsPlannedTrade {
    let intent: PerpsTradeIntent
    let context: PerpsMarketContext
    let marketSnapshot: PerpetualMarketSnapshot?
    let plan: PerpetualOperation

    var setsLeverage: Bool {
        plan.steps.contains { $0.stepId == PerpsPlannerHost.leverageStepId }
    }
}

final class PerpsPlannerHost {
    static let leverageStepId = "leverage"
    private static let maxFreshReads = 10
    private static let maxDepthReads = 4
    private static let maxIterations = 32

    private let api: PerpsAPI
    private let freshReadDelayNanoseconds: UInt64
    private let reissueReadOnlyToken: @Sendable () async -> Bool
    private let readIntegrator: @Sendable (String) async throws -> Components.Schemas.Integrator
    private let readSecurityConfig: @Sendable () async -> PerpsSecurityConfig?
    private let serverClock: PerpsServerClock
    private let mediator = LighterPerpsMediator()

    init(
        api: PerpsAPI,
        securityConfig: @escaping @Sendable () async -> PerpsSecurityConfig?,
        freshReadDelayNanoseconds: UInt64 = 1_000_000_000,
        serverClock: PerpsServerClock = .shared,
        readIntegrator: (@Sendable (String) async throws -> Components.Schemas.Integrator)? = nil,
        reissueReadOnlyToken: @escaping @Sendable () async -> Bool = { false }
    ) {
        self.api = api
        self.readIntegrator = readIntegrator ?? { walletId in try await api.integrator(walletId: walletId) }
        readSecurityConfig = securityConfig
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
        screenReads: PerpsTradingScreenReads? = nil,
        preRead: Task<Components.Schemas.TradingScreen, Error>? = nil
    ) async throws -> PerpsMarketContext {
        let now = PerpsPlannerMapping.nowUnixMs()
        // Neither read depends on the other, and this runs on every quote — serial would
        // put a second round trip in front of every price the user sees.
        async let screenRead = PerpsAPIError.reissuingReadOnlyToken(reissueReadOnlyToken) {
            if let preRead, let screen = try? await preRead.value {
                return screen
            }
            if let screenReads {
                return try await screenReads.tradingScreen(api: api, walletId: walletId, marketId: marketId)
            }
            return try await api.tradingScreen(walletId: walletId, marketId: marketId)
        }
        async let integratorRead = readIntegrator(walletId)
        async let securityConfigRead = readSecurityConfig()
        let screen = try await screenRead
        if let serverOffset = serverClock.serverOffsetMs, PerpsServerClock.isDeviceClockSkewed(serverOffsetMs: serverOffset) {
            PerpsOperationLog.event("clock", outcome: "failed", error: PerpsTradingError.deviceClockSkew, fields: ["market_id": String(marketId), "server_offset_ms": String(serverOffset)])
            throw PerpsTradingError.deviceClockSkew
        }
        guard let market = screen.market else {
            throw PerpsTradingError.validation("trading screen has no market")
        }
        let integrator = try await integratorRead
        let securityConfig = await securityConfigRead
        try Task.checkCancellation()
        let signed: PerpsSignedMarket
        do {
            signed = try PerpsSignedMarketCheck.signedMarket(marketId: marketId, market: market, config: securityConfig)
            try PerpsMarketBinding.requireRequestedMarket(marketId, screen: screen)
        } catch {
            logSignedMarketRefusal(error, marketId: marketId)
            throw error
        }
        let rules = try PerpsPlannerMapping.rules(
            market: market,
            signed: signed,
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
                do {
                    try PerpsMarketBinding.requireRequestedMarket(marketId, detail: detail)
                } catch {
                    logSignedMarketRefusal(error, marketId: marketId)
                    throw error
                }
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
            ordersKnown: ordersKnown
        )
        if !ordersKnown {
            PerpsOperationLog.event("context", outcome: "orders_unreadable", source: "backend", fields: ["market_id": String(marketId), "cancel_enabled": screen.flags?.cancel_enabled.map(String.init) ?? "nil", "position_present": String(screen.position != nil)])
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
            venueTakerFeePpm: integrator.venue_taker_fee.map(Int64.init),
            accountSnapshot: tradingContext,
            marketSnapshot: nil,
            symbol: signed.symbol,
            leverage: screen.position?.value1.leverage.map(Double.init),
            entryPrice: PerpsMarketMath.optionalDouble(screen.position?.value1.avg_entry_price),
            limitOrders: PerpsBackendMapping.limitOrders(screen.open_orders),
            mark: mark,
            nowUnixMs: now
        )
    }

    func plan(intent: PerpsTradeIntent, context: PerpsMarketContext) async throws -> PerpsPlannedTrade {
        return try await PerpsOperationLog.step("plan", fields: ["flow": "trade", "wallet_id": context.walletId, "market_id": String(context.rules.marketId), "operation_id": intent.operationId]) {
            let need = PerpsPlannerMapping.snapshotNeed(intent: intent, context: context)
            var coverage = need.coverageQuote
            for _ in 0 ..< Self.maxDepthReads {
                let snapshot = try await marketSnapshot(for: intent, context: context, coverageQuote: coverage)
                do {
                    let plan = try prepare(intent: intent, context: context, marketSnapshot: snapshot)
                    PerpsOperationLog.event("plan", outcome: "ready", fields: ["operation_id": plan.operationId, "steps": plan.steps.map(\.stepId).joined(separator: ","), "valid_until_ms": String(plan.validUntilUnixMs), "coverage": String(coverage)])
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
                    PerpsOperationLog.event("plan", outcome: "more_depth_required", fields: ["coverage": String(coverage), "next_coverage": String(coverage * 2)])
                    coverage *= 2
                }
            }
            PerpsOperationLog.event("plan", outcome: "failed", error: PerpsTradingError.insufficientLiquidity, fields: ["coverage": String(coverage)])
            throw PerpsTradingError.insufficientLiquidity
        }
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
        execution: PerpsExecutionDelegate
    ) async throws {
        return try await PerpsOperationLog.step("execute", source: "wallet", fields: ["flow": "trade", "operation_id": planned.plan.operationId, "wallet_id": planned.context.walletId, "market_id": String(planned.context.rules.marketId), "account_index": String(planned.context.scope.accountIndex)]) {
            let intent = planned.intent
            var applied = [PerpsAppliedPrerequisite]()
            let currentPlan = planned.plan
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
                        serverClock.signingNowUnixMs(deviceNowUnixMs: now) + LighterConstants.shared.DefaultExpireTimeMillis,
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
                        let mapped = PerpsTradingErrorMapper.map(error)
                        PerpsOperationLog.event("execute_step", outcome: "failed", source: mapped.operationLogSource, error: error, fields: mapped.operationLogFields.merging(["step_id": step.stepId]) { _, new in new })
                        throw mapped
                    }
                    applied.append(prerequisite(for: step, plan: currentPlan, intent: intent, context: currentContext))
                    completedStepIds.insert(step.stepId)
                case .alreadySettled:
                    PerpsOperationLog.event("validate_step", outcome: "already_settled", fields: ["step_id": step.stepId])
                    completedStepIds.insert(step.stepId)
                case .requiresFreshContext:
                    guard freshReads < Self.maxFreshReads else {
                        throw Self.unfinished(applied)
                    }
                    freshReads += 1
                    PerpsOperationLog.event("validate_step", outcome: "fresh_context_required", fields: ["step_id": step.stepId, "read": String(freshReads)])
                    try await Task.sleep(nanoseconds: freshReadDelayNanoseconds)
                    currentContext = try await refresh(context: currentContext)
                case let .requiresPrepare(reason):
                    // A new plan is a trade nobody reviewed; the user gets a fresh review instead.
                    PerpsOperationLog.event("validate_step", outcome: "replan_required", fields: ["step_id": step.stepId, "reason": String(describing: reason), "applied_steps": String(applied.count)])
                    throw Self.unfinished(applied)
                case .requiresAppliedStep:
                    throw Self.unfinished(applied)
                }
            }
        }
    }

    private static func unfinished(_ applied: [PerpsAppliedPrerequisite]) -> PerpsTradingError {
        applied.isEmpty ? .stalePreparedTransaction : .operationInProgress
    }

    private func logSignedMarketRefusal(_ error: Error, marketId: Int64) {
        let reason = (error as? PerpsSignedMarketRefusal)?.reason ?? "no_verified_config"
        PerpsOperationLog.event("signed_market", outcome: "refused", error: PerpsTradingErrorMapper.map(error), fields: ["market_id": String(marketId), "reason": reason])
    }
}

extension PerpsMarketContext {
    func withMarketSnapshot(_ snapshot: PerpetualMarketSnapshot?) -> PerpsMarketContext {
        PerpsMarketContext(
            walletId: walletId,
            scope: scope,
            rules: rules,
            venueTakerFeePpm: venueTakerFeePpm,
            accountSnapshot: accountSnapshot,
            marketSnapshot: snapshot,
            symbol: symbol,
            leverage: leverage,
            entryPrice: entryPrice,
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
            PerpsOperationLog.event("clock", outcome: "failed", error: PerpsTradingError.deviceClockSkew, fields: ["market_id": String(context.rules.marketId), "book_updated_at_ms": String(bookUpdatedAt), "device_now_ms": String(now)])
            throw PerpsTradingError.deviceClockSkew
        }
        let levels = (side === PerpsSide.short_ ? book.bids : book.asks) ?? []
        PerpsOperationLog.event("order_book", outcome: "loaded", source: "backend", fields: ["market_id": String(context.rules.marketId), "side": PerpsPlannerMapping.bookSide(side).rawValue, "notional": notional, "levels": String(levels.count), "truncated": String(book.truncated), "updated_at_ms": String(bookUpdatedAt)])
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
        if step.stepId == Self.leverageStepId {
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
