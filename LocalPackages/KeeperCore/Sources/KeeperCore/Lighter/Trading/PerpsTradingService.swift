import ChainKit
import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

public struct PerpsTradingConfig: Sendable {
    public let defaultLeverage: Double
    public let minLeverage: Double
    public let maxSlippage: Double
    /// Close and reduce are IOCs that must actually fill — a bound too tight for the
    /// book cancels with zero filled and the position silently stays open/unchanged,
    /// so both trade a wider bound for fill certainty.
    public let closeMaxSlippage: Double

    public init(
        defaultLeverage: Double = 20,
        minLeverage: Double = 1,
        maxSlippage: Double = 0.05,
        closeMaxSlippage: Double = 0.05
    ) {
        self.defaultLeverage = defaultLeverage
        self.minLeverage = minLeverage
        self.maxSlippage = maxSlippage
        self.closeMaxSlippage = closeMaxSlippage
    }
}

final class PerpsTkTradingService: PerpsTradingService, @unchecked Sendable {
    private let accountService: PerpsAccountService
    private let wallet: Wallet
    private let journal: PerpsPendingJournal
    private let readOnlyToken: PerpsReadOnlyToken
    private let perpsAPI: PerpsAPI
    private let markPriceProvider: @Sendable (Int64) async -> Double?
    private let marketProvider: @Sendable (Int64) async -> PerpsMarketMetadata?
    private let config: PerpsTradingConfig
    private let intents: PerpsChainIntents
    private let host: PerpsPlannerHost
    private let tradingScreenReads: PerpsTradingScreenReads
    private let operationJournaled: @Sendable () -> Void
    private let tradeBegan: @Sendable (_ operationId: String, _ marketId: Int64, _ trade: PerpsTradeInProgress) -> Void
    private let tradeSettled: @Sendable (_ operationId: String, _ succeeded: Bool) -> Void
    private let positionCounted: @Sendable (_ operationId: String, _ position: PerpsCountedPosition) -> Void
    private let positionClosed: @Sendable (_ operationId: String, _ marketId: Int64) async -> Void
    private let liveFeed: PerpsLiveFeed

    static let autoCloseRenewalLeadSeconds: Int64 = 7 * 24 * 60 * 60

    init(
        accountService: PerpsAccountService,
        wallet: Wallet,
        journal: PerpsPendingJournal,
        readOnlyToken: PerpsReadOnlyToken,
        perpsAPI: PerpsAPI,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?,
        config: PerpsTradingConfig = PerpsTradingConfig(),
        tradingScreenReads: PerpsTradingScreenReads = PerpsTradingScreenReads(),
        operationJournaled: @escaping @Sendable () -> Void = {},
        tradeBegan: @escaping @Sendable (_ operationId: String, _ marketId: Int64, _ trade: PerpsTradeInProgress) -> Void = { _, _, _ in },
        tradeSettled: @escaping @Sendable (_ operationId: String, _ succeeded: Bool) -> Void = { _, _ in },
        positionCounted: @escaping @Sendable (_ operationId: String, _ position: PerpsCountedPosition) -> Void = { _, _ in },
        positionClosed: @escaping @Sendable (_ operationId: String, _ marketId: Int64) async -> Void = { _, _ in },
        liveFeed: PerpsLiveFeed = PerpsLiveFeed(signals: { AsyncStream { $0.finish() } }),
        securityConfig: (@Sendable () async -> PerpsSecurityConfig?)? = nil,
        freshReadDelayNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.accountService = accountService
        self.wallet = wallet
        self.journal = journal
        self.readOnlyToken = readOnlyToken
        self.perpsAPI = perpsAPI
        self.markPriceProvider = markPriceProvider
        self.marketProvider = marketProvider
        self.config = config
        intents = PerpsChainIntents(config: config)
        self.tradingScreenReads = tradingScreenReads
        self.operationJournaled = operationJournaled
        self.tradeBegan = tradeBegan
        self.tradeSettled = tradeSettled
        self.positionCounted = positionCounted
        self.positionClosed = positionClosed
        self.liveFeed = liveFeed
        host = PerpsPlannerHost(
            api: perpsAPI,
            securityConfig: securityConfig ?? { [accountService] in await accountService.verifiedSecurityConfig() },
            freshReadDelayNanoseconds: freshReadDelayNanoseconds,
            readIntegrator: { [accountService] walletId in try await accountService.integrator(walletId: walletId) }
        ) { [readOnlyToken] in
            await readOnlyToken.issue()
        }
    }

    func openMarketContext(marketId: Int64, side: PerpsTradeSide) async -> PerpsOpenMarketContext? {
        if let walletId = try? requireWalletId() {
            accountService.refreshIntegrator(walletId: walletId)
        }
        guard let market = await marketProvider(marketId) else {
            PerpsOperationLog.event("market_context", outcome: "unavailable", source: "backend", fields: ["flow": "trade", "action": "open", "market_id": String(marketId), "reason": "market_metadata_unavailable"])
            return nil
        }
        let maxLeverage = max(config.minLeverage, market.maxLeverage)
        let displayPrice = await markPriceProvider(marketId) ?? market.displayPrice
        return PerpsOpenMarketContext(
            marketId: marketId,
            side: side,
            symbol: market.symbol,
            displayPrice: displayPrice,
            priceDecimals: market.priceDecimals,
            sizeDecimals: market.sizeDecimals,
            leverageBounds: PerpsLeverageBounds(min: config.minLeverage, max: maxLeverage),
            defaultLeverage: min(max(config.defaultLeverage, config.minLeverage), maxLeverage),
            maxSlippage: config.maxSlippage,
            minBaseSize: market.minBaseSize,
            minNotionalUsd: market.minNotionalUsd
        )
    }

    func previewOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsOpenOrderReview, PerpsTradingError> {
        await attempt("preview open", fields: intent.operationLogFields) {
            guard (PerpsMarketMath.optionalDouble(intent.marginUsd) ?? 0) > 0 else {
                throw PerpsTradingError.validation("amount is empty or invalid")
            }
            let context = try await reviewContext(marketId: intent.marketId)
            let chainIntent = try await intents.open(
                intent,
                context: context,
                operationId: UUID().uuidString,
                clientOrderIndices: intents.clientOrderIndices(for: context)
            )
            let planned = try await host.plan(intent: chainIntent, context: context)
            guard let review = planned.plan.review as? PerpetualReview.Open else {
                throw PerpsTradingError.protocolFailure("unexpected open review")
            }
            return PerpsPlannerMapping.openReview(
                review,
                symbol: await resolvedSymbol(context, marketId: intent.marketId),
                feePpm: context.displayedTakerFeePpm(.open),
                setsIsolatedMargin: planned.setsLeverage
            )
        }
    }

    func warmSubmit(marketId: Int64) {
        Task { [weak self] in
            guard let self,
                  let session = try? await accountService.tradingSession(wallet: wallet),
                  let walletId = try? requireWalletId()
            else { return }
            let api = perpsAPI
            let readOnlyToken = readOnlyToken
            await accountService.submitLanes.lane(for: session).preRead(marketId: marketId) {
                try await PerpsAPIError.reissuingReadOnlyToken({ await readOnlyToken.issue() }) {
                    try await api.tradingScreen(walletId: walletId, marketId: marketId)
                }
            }
        }
    }

    func dropWarmSubmit(marketId: Int64) {
        Task { [weak self] in
            guard let self, let session = try? await accountService.tradingSession(wallet: wallet) else { return }
            await accountService.submitLanes.lane(for: session).dropPreRead(marketId: marketId)
        }
    }

    func reportWait(_ wait: PerpsTradeWait, milliseconds: Int64) {
        guard let walletId = try? requireWalletId() else { return }
        let id = UUID().uuidString
        let metric: Components.Schemas.ClientMetric = switch wait {
        case .positionOpen: .position_open(.init(id: id, _type: .position_open, duration_ms: milliseconds))
        case .positionClose: .position_close(.init(id: id, _type: .position_close, duration_ms: milliseconds))
        }
        let api = perpsAPI
        Task {
            do {
                try await api.recordClientMetrics(walletId: walletId, metrics: [metric])
            } catch {
                PerpsOperationLog.event("client_metric", outcome: "failed", error: error)
            }
        }
    }

    func openSubmission(_ intent: PerpsOpenMarketIntent, review: PerpsOpenOrderReview) -> PerpsPreparedTradingAction {
        PerpsPreparedTradingAction(
            operationId: UUID().uuidString,
            walletId: wallet.id,
            marketId: intent.marketId,
            intent: intent,
            review: review
        )
    }

    func submit(_ prepared: PerpsPreparedTradingAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        let opening = PerpsOpeningDescriptor(
            marketId: prepared.marketId,
            symbol: prepared.review.symbol,
            side: prepared.intent.side,
            marginUsd: prepared.review.marginUsd,
            leverage: prepared.intent.leverage,
            isLimit: prepared.intent.limitPrice != nil,
            liquidationPrice: prepared.review.liquidationPrice
        )
        return await submitAction(prepared, inProgress: .opening(opening), passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planOpen(
                prepared.intent,
                session: session,
                operationId: prepared.operationId,
                takesPreRead: true
            )
            guard prepared.review.admits(planned.review) else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            let action = pending(
                prepared,
                side: prepared.intent.side,
                payload: .open(limitPrice: prepared.intent.limitPrice),
                expectedBaseSize: planned.review.baseSize
            )
            return Submission(
                pending: action,
                followUps: PerpsAutoCloseRebase.followUps(
                    pending: action,
                    planned: planned.planned,
                    takeProfitROIPercent: prepared.intent.takeProfitROIPercent,
                    stopLossROIPercent: prepared.intent.stopLossROIPercent,
                    leverage: prepared.intent.leverage
                ),
                execute: { execution in
                    // Recorded before signing: nothing rests on a flat market until this open lands,
                    // and an open whose send outcome is unknown may still land.
                    await self.confirmAutoClose(marketId: prepared.marketId) { [autoClose = planned.autoClose] _ in autoClose }
                    try await self.host.execute(
                        planned: planned.planned,
                        signingKey: await self.signingKey(accountIndex: session.accountIndex),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedCloseAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        await submitAction(prepared, inProgress: .closing, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planClose(
                marketId: prepared.marketId,
                context: self.marketContext(session: session, marketId: prepared.marketId),
                operationId: prepared.operationId
            )
            guard prepared.review.admits(planned.review) else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            return Submission(
                pending: pending(
                    prepared,
                    side: prepared.review.side,
                    payload: .close,
                    expectedBaseSize: PerpsScaled.double(
                        planned.baseAmount,
                        decimals: planned.planned.context.rules.scale.baseDecimals
                    ),
                    positionBaseSizeBefore: PerpsScaled.double(
                        planned.baseAmount,
                        decimals: planned.planned.context.rules.scale.baseDecimals
                    )
                ),
                execute: { execution in
                    try await self.host.execute(
                        planned: planned.planned,
                        signingKey: await self.signingKey(accountIndex: session.accountIndex),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedSizeChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        let adjusting = PerpsTradeInProgress.adjusting(prepared.intent.direction, baseSizeBefore: prepared.review.baseSize.old)
        return await submitAction(prepared, inProgress: adjusting, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planSizeChange(
                prepared.intent,
                context: self.marketContext(session: session, marketId: prepared.intent.marketId),
                operationId: prepared.operationId,
                normalizedAutoClose: prepared.normalizedAutoClose
            )
            guard prepared.review.admits(planned.review) else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            let action = pending(
                prepared,
                side: PerpsPlannerMapping.tradeSide(planned.side),
                payload: .sizeChange(
                    PerpsPendingSizeChange(
                        direction: prepared.intent.direction,
                        baseSizeBefore: PerpsScaled.double(
                            planned.baseAmount,
                            decimals: planned.planned.context.rules.scale.baseDecimals
                        ),
                        expectedBaseDelta: abs(planned.review.baseSize.new - planned.review.baseSize.old)
                    ),
                    autoClose: planned.pendingAutoClose
                )
            )
            return Submission(
                pending: action,
                followUps: PerpsAutoCloseRebase.followUps(
                    pending: action,
                    planned: planned.planned,
                    takeProfitROIPercent: prepared.intent.takeProfitROIPercent,
                    stopLossROIPercent: prepared.intent.stopLossROIPercent,
                    leverage: planned.planned.context.leverage
                ),
                execute: { execution in
                    try await self.host.execute(
                        planned: planned.planned,
                        signingKey: await self.signingKey(accountIndex: session.accountIndex),
                        execution: execution
                    )
                    if let target = planned.pendingAutoClose.map(\.target) {
                        await self.confirmAutoClose(marketId: prepared.marketId) { _ in target }
                    }
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedMarginChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        let adjustingMargin = PerpsTradeInProgress.adjustingMargin(
            prepared.intent.direction,
            allocatedMarginBefore: prepared.review.allocatedMargin.old,
            amountUsd: prepared.review.amountUsd
        )
        return await submitAction(prepared, inProgress: adjustingMargin, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planMarginChange(
                prepared.intent,
                context: self.marketContext(session: session, marketId: prepared.intent.marketId),
                operationId: prepared.operationId
            )
            if prepared.intent.direction == .reduce, planned.isImmediateRisk {
                throw PerpsTradingError.immediateLiquidationRisk
            }
            guard prepared.review.admits(planned.review) else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            return Submission(
                pending: pending(
                    prepared,
                    side: PerpsPlannerMapping.tradeSide(planned.side),
                    payload: .marginChange(PerpsPendingMarginChange(
                        direction: prepared.intent.direction,
                        allocatedMarginBefore: PerpsScaled.double(
                            planned.allocatedBefore,
                            decimals: planned.planned.context.rules.scale.quoteDecimals
                        ),
                        amountUsd: planned.amount
                    ))
                ),
                execute: { execution in
                    try await self.host.execute(
                        planned: planned.planned,
                        signingKey: await self.signingKey(accountIndex: session.accountIndex),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedAutoCloseChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        await submitAction(prepared, inProgress: nil, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planAutoCloseChange(
                prepared.intent,
                session: session,
                operationId: prepared.operationId
            )
            guard planned.review == prepared.review else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            return Submission(
                pending: pending(prepared, side: planned.review.side, payload: .autoCloseChange(PerpsPendingAutoCloseChange(
                    target: planned.review.new,
                    restingOrderIndexes: planned.cancelIndexes
                ))),
                execute: { execution in
                    try await self.host.execute(
                        planned: planned.planned,
                        signingKey: await self.signingKey(accountIndex: session.accountIndex),
                        execution: execution
                    )
                    await self.confirmAutoClose(marketId: prepared.marketId) { [target = planned.review.new] _ in target }
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        await submitAction(prepared, inProgress: nil, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planLimitOrderChange(
                prepared.intent,
                session: session,
                operationId: prepared.operationId
            )
            guard planned.review.order.orderIndex == prepared.review.order.orderIndex else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            if prepared.review.kind == .modify,
               !PerpsLimitOrderChangeSettlement.pricesMatch(
                   planned.review.order.limitPrice,
                   prepared.review.order.limitPrice
               ) || planned.review.baseAmount > prepared.review.baseAmount
            {
                throw PerpsTradingError.stalePreparedTransaction
            }
            return Submission(
                pending: pending(prepared, side: planned.review.order.side, payload: .limitOrderChange(PerpsPendingLimitOrderChange(
                    orderIndex: planned.review.order.orderIndex,
                    kind: planned.review.kind,
                    limitPrice: planned.review.limitPrice,
                    orderId: planned.review.order.id.nilIfEmpty
                ))),
                execute: { execution in
                    try await self.host.execute(
                        planned: planned.planned,
                        signingKey: await self.signingKey(accountIndex: session.accountIndex),
                        execution: execution
                    )
                }
            )
        }
    }

    func previewClose(
        _ intent: PerpsCloseIntent
    ) async -> Result<PerpsCloseReview, PerpsTradingError> {
        await attempt("preview close", fields: ["market_id": String(intent.marketId), "action": "close"]) {
            try await planClose(marketId: intent.marketId, context: reviewContext(marketId: intent.marketId)).review
        }
    }

    func prepareClose(
        _ intent: PerpsCloseIntent
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError> {
        await attempt("prepare close", fields: ["market_id": String(intent.marketId), "action": "close"]) {
            let session = try await requireSession()
            let planned = try await planClose(
                marketId: intent.marketId,
                context: marketContext(session: session, marketId: intent.marketId)
            )
            return PerpsPreparedCloseAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                review: planned.review
            )
        }
    }

    func previewSizeChange(
        _ intent: PerpsSizeChangeIntent
    ) async -> Result<PerpsSizeChangeReview, PerpsTradingError> {
        await attempt("preview size change", fields: intent.operationLogFields) {
            try await planSizeChange(intent, context: reviewContext(marketId: intent.marketId)).review
        }
    }

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError> {
        await attempt("prepare size change", fields: intent.operationLogFields) {
            let session = try await requireSession()
            let planned = try await planSizeChange(
                intent,
                context: marketContext(session: session, marketId: intent.marketId)
            )
            return PerpsPreparedSizeChangeAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                intent: intent,
                review: planned.review,
                normalizedAutoClose: planned.normalizedAutoClose
            )
        }
    }

    func previewMarginChange(
        _ intent: PerpsMarginChangeIntent
    ) async -> Result<PerpsMarginChangeReview, PerpsTradingError> {
        await attempt("preview margin change", fields: intent.operationLogFields) {
            try await planMarginChange(intent, context: reviewContext(marketId: intent.marketId)).review
        }
    }

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError> {
        await attempt("prepare margin change", fields: intent.operationLogFields) {
            let session = try await requireSession()
            let planned = try await planMarginChange(
                intent,
                context: marketContext(session: session, marketId: intent.marketId)
            )
            if intent.direction == .reduce, planned.isImmediateRisk {
                throw PerpsTradingError.immediateLiquidationRisk
            }
            return PerpsPreparedMarginChangeAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                intent: intent,
                review: planned.review
            )
        }
    }

    func prepareAutoCloseChange(
        _ intent: PerpsAutoCloseChangeIntent
    ) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError> {
        await attempt("prepare auto-close change", fields: intent.operationLogFields) {
            let session = try await requireSession()
            let planned = try await planAutoCloseChange(intent, session: session)
            return PerpsPreparedAutoCloseChangeAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                intent: intent,
                review: planned.review
            )
        }
    }

    func prepareLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent
    ) async -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError> {
        await attempt("prepare limit-order change", fields: intent.operationLogFields) {
            if case let .modify(_, _, limitPrice, _, _) = intent, !(limitPrice.isFinite && limitPrice > 0) {
                throw PerpsTradingError.validation("limit price is empty or invalid")
            }
            let session = try await requireSession()
            let planned = try await planLimitOrderChange(intent, session: session)
            return PerpsPreparedLimitOrderChangeAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                intent: intent,
                review: planned.review
            )
        }
    }

    func changes(marketId: Int64) async -> any PerpsChanges {
        await liveFeed.listen([.market(marketId), .account], debounce: 0, holdsSubscription: false)
    }

    /// One entry point for every operation: what to look at is in the payload, so
    /// no caller has to pick a method that matches the record it already holds.
    func reconcile(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        return await PerpsOperationLog.withContext(fields: pending.operationLogFields.merging(["trace_id": pending.operationId, "poll": "true"]) { _, new in new }) {
            guard wallet.id == pending.walletId else { return .pending }
            // The following extras reload must not join a screen read from before reconciliation.
            defer { tradingScreenReads.invalidate() }
            switch pending.payload {
            case let .open(limitPrice):
                var counted: PerpsCountedPosition?
                let result = await reconcileByState(pending, label: "open") { state in
                    let heard = PerpsTkReconcile.open(
                        state: state,
                        isLimit: limitPrice != nil,
                        expectedBaseSize: pending.expectedBaseSize
                    )
                    if limitPrice == nil, heard == .confirmed {
                        counted = PerpsTkReconcile.countedOpen(state: state)
                    }
                    guard limitPrice != nil, heard == .pending, let ref = pending.positionOrderRef,
                          let screen = try? await self.loadTradingScreen(marketId: pending.marketId)
                    else { return heard }
                    return PerpsTkReconcile.limitOpen(
                        heard: heard,
                        openOrders: screen.open_orders,
                        clientOrderIndex: ref.clientOrderIndex
                    )
                }
                if result == .confirmed, var counted {
                    counted.markPrice = await markPriceProvider(pending.marketId)
                    positionCounted(pending.operationId, counted)
                }
                return result
            case .close:
                let result = await reconcileByState(pending, label: "close") { state in
                    PerpsTkReconcile.close(
                        state: state,
                        expectedBaseSize: pending.expectedBaseSize ?? pending.positionBaseSizeBefore
                    )
                }
                if result == .confirmed {
                    await positionClosed(pending.operationId, pending.marketId)
                }
                return result
            case let .sizeChange(change, autoClose):
                let position = await reconcileSizeChange(pending, change: change)
                guard let autoClose, position == .confirmed || position == .partiallyFilled else { return position }
                _ = await reconcileAutoClose(pending, change: autoClose)
                return position
            case let .marginChange(change):
                return await reconcileMargin(pending, change: change)
            case let .autoCloseChange(change):
                return await reconcileAutoClose(pending, change: change)
            case let .limitOrderChange(change):
                return await reconcileLimitOrder(pending, change: change)
            case .autoCloseRebase:
                return .pending
            }
        }
    }

    func reconcileLimitOrder(
        _ pending: PerpsPendingTradingAction,
        change: PerpsPendingLimitOrderChange
    ) async -> PerpsReconcileResult {
        await settle(pending, label: "limitOrderChange") {
            if let orderId = change.orderId,
               let detail = try? await self.perpsAPI.getOrder(walletId: self.requireWalletId(), id: orderId)
            {
                return PerpsTkReconcile.limitChange(change: change, detail: detail)
            }
            let screen = try await loadTradingScreen(marketId: pending.marketId)
            if change.orderId == nil, change.kind == .cancel, PerpsBackendMapping.ordersReadable(screen),
               PerpsBackendMapping.matchingOrder(screen.open_orders ?? [], orderIndex: change.orderIndex) == nil
            {
                return PerpsBackendMapping.autoCloseLeg(screen.open_orders, key: change.orderIndex) == nil ? .confirmed : .pending
            }
            return PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: PerpsBackendMapping.ordersReadable(screen),
                matching: PerpsBackendMapping.matchingOrder(
                    screen.open_orders ?? [],
                    orderIndex: change.orderIndex
                )
            )
        }
    }

    func reconcileSizeChange(
        _ pending: PerpsPendingTradingAction,
        change: PerpsPendingSizeChange
    ) async -> PerpsReconcileResult {
        guard let ref = pending.positionOrderRef else {
            return await settle(pending, label: "sizeChange") {
                pending.hasOnlyAcceptedSignedSteps ? .notSubmitted : .pending
            }
        }
        return await settle(pending, label: "sizeChange") {
            let state = try await loadPositionState(marketId: pending.marketId, clientOrderIndex: ref.clientOrderIndex)
            if let decision = PerpsTkReconcile.sizeChange(state: state, expectedBaseDelta: change.expectedBaseDelta) {
                return decision
            }
            let positions = try await loadAccountSnapshot().positions
            return PerpsTkReconcile.sizeChange(
                change,
                currentBaseSize: positions.first { $0.marketId == pending.marketId }?.baseSize
            )
        }
    }

    /// Each leg is asked about by its own key, since the state endpoint answers
    /// for one order at a time. What the venue holds is read whatever the legs
    /// said: a cancel creates no order to ask about, and a trigger order that was
    /// placed rests unheard-of until it fires.
    func reconcileAutoClose(
        _ pending: PerpsPendingTradingAction,
        change: PerpsPendingAutoCloseChange
    ) async -> PerpsReconcileResult {
        let result = await settle(pending, label: "autoClose") {
            var legs = [PerpsTkReconcile.Decision]()
            for ref in pending.triggerOrderRefs {
                let state = try await loadPositionState(
                    marketId: pending.marketId,
                    clientOrderIndex: ref.clientOrderIndex
                )
                legs.append(PerpsTkReconcile.autoCloseLeg(state: state))
            }
            let resting = try await restingTriggerOrders(marketId: pending.marketId, side: pending.side)
            return PerpsTkReconcile.autoCloseChange(
                legs: legs,
                restingMatchesTarget: resting.map {
                    PerpsAutoCloseChangePlanner.isConfirmed(pending: change, orders: $0)
                }
            )
        }
        if case .confirmed = result {
            await confirmAutoClose(marketId: pending.marketId) { _ in change.target }
        }
        return result
    }

    /// The trigger orders the venue holds for a market, or nil when neither the
    /// screen nor the position can say.
    func restingTriggerOrders(marketId: Int64, side: PerpsTradeSide) async throws -> [PerpsTriggerOrderSummary]? {
        let screen = try await loadTradingScreen(marketId: marketId)
        if PerpsBackendMapping.ordersReadable(screen) {
            return PerpsBackendMapping.triggerOrders(screen.open_orders)
        }
        guard let detail = try await loadOpenPositionDetail(marketId: marketId),
              detail.auto_close_known == true
        else {
            return nil
        }
        return PerpsBackendMapping.triggerOrders(autoClose: detail.auto_close?.value1, side: side)
    }

    /// A margin move has no order to ask about, and a vanished position never
    /// confirms: a liquidation racing the change is a different outcome.
    func reconcileMargin(
        _ pending: PerpsPendingTradingAction,
        change: PerpsPendingMarginChange
    ) async -> PerpsReconcileResult {
        await settle(pending, label: "marginChange") {
            let positions = try await loadAccountSnapshot().positions
            return PerpsTkReconcile.marginChange(
                change,
                currentMarginUsd: positions.first { $0.marketId == pending.marketId }?.marginUsd,
                canStillLand: pending.canStillLand(now: PerpsServerClock.shared.signingNowUnixMs())
            )
        }
    }

    func recoverInterruptedOperations() async -> Bool {
        guard !Task.isCancelled else { return true }
        do {
            guard try await !journal.allPending().isEmpty,
                  let session = try await accountService.tradingSession(wallet: wallet)
            else { return true }
            let lane = await accountService.submitLanes.lane(for: session)
            _ = try await lane.run {
                try await recoverLocalPendingInLane(excluding: nil, lane: lane)
            }
            return try await journal.allPending().isEmpty
        } catch {
            guard !Task.isCancelled else { return true }
            let mapped = PerpsTradingErrorMapper.map(error)
            PerpsOperationLog.event("recovery", outcome: "failed", source: mapped.operationLogSource, error: error, fields: ["flow": "trade", "wallet_id": format2WalletId() ?? wallet.id])
            return false
        }
    }

    func renewExpiringAutoClose(marketIds: [Int64]) async -> Bool {
        guard let session = try? await accountService.tradingSession(wallet: wallet) else { return false }
        let deadline = PerpsPlannerMapping.nowUnixMs() / 1000 + Self.autoCloseRenewalLeadSeconds
        var everyMarketSettled = true
        for marketId in marketIds {
            guard !Task.isCancelled else { return false }
            let context: PerpsMarketContext
            do {
                context = try await marketContext(session: session, marketId: marketId)
            } catch is PerpsSignedMarketRefusal {
                continue
            } catch {
                everyMarketSettled = false
                continue
            }
            guard !(context.accountSnapshot.completeness is PerpsContextCompleteness.Incomplete) else {
                everyMarketSettled = false
                continue
            }
            let resting = intents.restingTriggerOrders(context)
            guard resting.contains(where: { $0.expiresAtSeconds > 0 && $0.expiresAtSeconds < deadline }) else { continue }
            // Only triggers this device signed are signed again in the background; the backend's
            // reading of them is compared against that record, never used as the price.
            let signed: PerpsAutoClose?
            do {
                signed = try await journal.confirmedAutoClose(marketId: marketId)
            } catch {
                PerpsOperationLog.event("auto_close_renewal", outcome: "failed", error: error, fields: ["market_id": String(marketId)])
                everyMarketSettled = false
                continue
            }
            guard let signed, PerpsAutoCloseChangePlanner.matches(target: signed, resting: resting) else {
                PerpsOperationLog.event("auto_close_renewal", outcome: "skipped", fields: ["market_id": String(marketId), "reason": signed == nil ? "not_signed_here" : "differs_from_signed"])
                continue
            }
            guard case let .success(prepared) = await prepareAutoCloseChange(
                PerpsAutoCloseChangeIntent(marketId: marketId, target: signed, renewsExpiry: true)
            ) else {
                everyMarketSettled = false
                continue
            }
            let result = await submit(prepared, passcodeProvider: { nil })
            if case .failed = result { everyMarketSettled = false }
        }
        return everyMarketSettled && !Task.isCancelled
    }

    func marketsBlockedByPending() async -> Set<Int64> {
        guard let pendings = try? await journal.allPending() else { return [] }
        let signingNow = PerpsServerClock.shared.signingNowUnixMs()
        return Set(pendings.filter { $0.blocksPositionOrders(now: signingNow) }.map(\.marketId))
    }

    func loadReviewer(
        for intent: PerpsOpenMarketIntent
    ) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        await loadReviewer(marketId: intent.marketId) { context in
            try self.intents.open(
                intent,
                context: context,
                operationId: UUID().uuidString,
                clientOrderIndices: PerpsPlannerMapping.reviewClientOrderIndices()
            )
        }
    }

    func loadReviewer(
        for intent: PerpsMarginChangeIntent
    ) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        await loadReviewer(marketId: intent.marketId) { context in
            try self.intents.margin(
                intent,
                context: context,
                present: context.requirePosition(),
                operationId: UUID().uuidString
            )
        }
    }

    func marginChangeLimits(marketId: Int64) async -> Result<PerpsMarginChangeLimits, PerpsTradingError> {
        await attempt("margin change limits", fields: ["market_id": String(marketId)]) {
            try PerpsPlannerMapping.marginChangeLimits(context: await reviewContext(marketId: marketId))
        }
    }

    func sizeChangeLimits(marketId: Int64) async -> Result<PerpsSizeChangeLimits, PerpsTradingError> {
        await attempt("size change limits", fields: ["market_id": String(marketId)]) {
            try PerpsPlannerMapping.sizeChangeLimits(context: await reviewContext(marketId: marketId))
        }
    }
}

private extension PerpsTkTradingService {
    struct Submission {
        let pending: PerpsPendingTradingAction
        var followUps: [PerpsPendingTradingAction] = []
        let execute: (_ execution: PerpsExecutionDelegate) async throws -> Void
    }

    struct PlannedOpen {
        let operationId: String
        let planned: PerpsPlannedTrade
        let review: PerpsOpenOrderReview
        let autoClose: PerpsAutoClose?
    }

    struct PlannedClose {
        let operationId: String
        let planned: PerpsPlannedTrade
        let review: PerpsCloseReview
        let side: PerpsSide
        let baseAmount: Int64
    }

    struct PlannedSizeChange {
        let operationId: String
        let planned: PerpsPlannedTrade
        let review: PerpsSizeChangeReview
        let side: PerpsSide
        let baseAmount: Int64
        let normalizedAutoClose: PerpsAutoClose?
        let pendingAutoClose: PerpsPendingAutoCloseChange?
    }

    struct PlannedMarginChange {
        let operationId: String
        let planned: PerpsPlannedTrade
        let review: PerpsMarginChangeReview
        let side: PerpsSide
        let allocatedBefore: Int64
        let amount: Double
        let isImmediateRisk: Bool
    }

    struct PlannedAutoClose {
        let operationId: String
        let planned: PerpsPlannedTrade
        let review: PerpsAutoCloseChangeReview
        let cancelIndexes: [Int64]
    }

    struct PlannedLimitChange {
        let operationId: String
        let planned: PerpsPlannedTrade
        let review: PerpsLimitOrderChangeReview
    }

    var environmentName: String {
        PerpsEnvironment.venue
    }

    var chainId: Int32 {
        LighterConstants.shared.ChainId
    }

    func format2WalletId() -> String? {
        wallet.multichainWalletState?.walletId
    }

    func requireWalletId() throws -> String {
        guard let walletId = format2WalletId(), !walletId.isEmpty else {
            throw PerpsTradingError.activationRequired
        }
        return walletId
    }

    func requireSession() async throws -> PerpsAccountSession {
        guard let session = try await accountService.tradingSession(wallet: wallet) else {
            throw PerpsTradingError.activationRequired
        }
        return session
    }

    func makeScope(accountIndex: Int64, apiKeyIndex: Int32) async throws -> PerpsScope {
        let key = try await signingKey(accountIndex: accountIndex)
        return try PerpsScope(
            walletId: requireWalletId(),
            venue: PerpsPlannerMapping.venue,
            chainId: chainId,
            environment: environmentName,
            accountIndex: accountIndex,
            keyBindingId: "\(accountIndex)/\(apiKeyIndex)",
            expectedPublicKey: key.publicKeyHex
        )
    }

    func signingKey(accountIndex: Int64) async throws -> PerpsSigningKey {
        guard let hex = try await accountService.loadL2PrivateKeyHex(wallet: wallet), !hex.isEmpty else {
            throw PerpsTradingError.credentialsRevoked
        }
        return try host.signingKey(
            privateKeyHex: hex,
            accountIndex: accountIndex,
            chainId: chainId
        )
    }

    func resolvedSymbol(_ context: PerpsMarketContext, marketId: Int64) async -> String {
        if let symbol = context.symbol, !symbol.isEmpty {
            return symbol
        }
        return await marketProvider(marketId)?.symbol ?? ""
    }

    func marketContext(
        session: PerpsAccountSession,
        marketId: Int64,
        preRead: Task<Components.Schemas.TradingScreen, Error>? = nil
    ) async throws -> PerpsMarketContext {
        try await host.context(
            walletId: requireWalletId(),
            marketId: marketId,
            scope: await makeScope(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex),
            environment: environmentName,
            liveMark: await markPriceProvider(marketId),
            preRead: preRead
        )
    }

    /// The one place a thrown error becomes a domain failure, so every entry point
    /// that can throw reads as the work it does rather than as its error tail.
    func attempt<T>(_ operation: String, fields: [String: String] = [:], _ body: () async throws -> T) async -> Result<T, PerpsTradingError> {
        let fields = fields.merging(["flow": "trade", "wallet_id": format2WalletId() ?? wallet.id]) { _, new in new }
        return await PerpsOperationLog.withContext(fields: fields) {
            let stage = operation.replacingOccurrences(of: " ", with: "_")
            PerpsOperationLog.event(stage, outcome: "started")
            do {
                let value = try await body()
                PerpsOperationLog.event(stage, outcome: "ready", fields: (value as? any PerpsPreparedAction)?.operationLogFields ?? [:])
                return .success(value)
            } catch {
                let mapped = PerpsTradingErrorMapper.map(error)
                let outcome: String
                switch mapped {
                case .activationCanceled: outcome = "cancelled"
                case .nothingToChange: outcome = "noop"
                default: outcome = "failed"
                }
                PerpsOperationLog.event(stage, outcome: outcome, source: mapped.operationLogSource, error: error, fields: mapped.operationLogFields)
                return .failure(mapped)
            }
        }
    }

    func reviewContext(marketId: Int64) async throws -> PerpsMarketContext {
        let walletId = try requireWalletId()
        return try await host.context(
            walletId: walletId,
            marketId: marketId,
            scope: PerpsScope.companion.review(
                walletId: walletId,
                venue: PerpsPlannerMapping.venue,
                chainId: chainId,
                environment: environmentName,
                accountIndex: 0
            ),
            environment: environmentName,
            liveMark: await markPriceProvider(marketId),
            // Only reviews join a read already in flight: submits and reconciles decide on what
            // the venue holds after the user's action, which a read that started earlier may miss.
            screenReads: tradingScreenReads
        )
    }

    func loadReviewer(
        marketId: Int64,
        intent: @escaping (PerpsMarketContext) throws -> PerpsTradeIntent
    ) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        await attempt("load reviewer", fields: ["market_id": String(marketId)]) {
            let context = try await reviewContext(marketId: marketId)
            let tradeIntent = try intent(context)
            let planned = try await host.plan(intent: tradeIntent, context: context)
            let inputs = PerpsReviewInputs(
                context: planned.context,
                marketSnapshot: planned.marketSnapshot,
                symbol: await resolvedSymbol(context, marketId: marketId)
            )
            return PerpsSnapshotReviewer(host: host, intents: intents, inputs: inputs)
        }
    }

    func planOpen(
        _ intent: PerpsOpenMarketIntent,
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString,
        takesPreRead: Bool = false
    ) async throws -> PlannedOpen {
        guard (PerpsMarketMath.optionalDouble(intent.marginUsd) ?? 0) > 0 else {
            throw PerpsTradingError.validation("amount is empty or invalid")
        }
        var preRead: Task<Components.Schemas.TradingScreen, Error>?
        if takesPreRead {
            preRead = await accountService.submitLanes.lane(for: session).takePreRead(marketId: intent.marketId)
            PerpsOperationLog.event("pre_read", outcome: preRead == nil ? "none" : "taken", fields: ["market_id": String(intent.marketId)])
        }
        let context = try await marketContext(session: session, marketId: intent.marketId, preRead: preRead)
        let chainIntent = try await intents.open(
            intent,
            context: context,
            operationId: operationId,
            clientOrderIndices: intents.clientOrderIndices(for: context)
        )
        let planned = try await host.plan(intent: chainIntent, context: context)
        guard let review = planned.plan.review as? PerpetualReview.Open else {
            throw PerpsTradingError.protocolFailure("unexpected open review")
        }
        let symbol = await resolvedSymbol(context, marketId: intent.marketId)
        return PlannedOpen(
            operationId: operationId,
            planned: planned,
            review: PerpsPlannerMapping.openReview(
                review,
                symbol: symbol,
                feePpm: context.displayedTakerFeePpm(.open),
                setsIsolatedMargin: planned.setsLeverage
            ),
            autoClose: PerpsPlannerMapping.autoClose(
                takeProfit: review.takeProfitTrigger,
                stopLoss: review.stopLossTrigger,
                decimals: review.scale.priceDecimals
            )
        )
    }

    func planClose(
        marketId: Int64,
        context: PerpsMarketContext,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedClose {
        let clientOrderIndices = try await intents.clientOrderIndices(for: context)
        let present = try context.requirePosition()
        let chainIntent = PerpsTradeIntent.Close(
            operationId: operationId,
            scope: context.scope,
            marketId: marketId,
            positionId: present.positionId,
            side: present.side,
            positionBaseAmount: present.baseAmount,
            baseAmount: nil,
            maxSlippagePpm: KotlinLong(value: PerpsPlannerMapping.slippagePpm(config.closeMaxSlippage)),
            clientOrderIndex: clientOrderIndices.order,
            autoClose: nil
        )
        let planned = try await host.plan(intent: chainIntent, context: context)
        guard let review = planned.plan.review as? PerpetualReview.Close else {
            throw PerpsTradingError.protocolFailure("unexpected close review")
        }
        let symbol = await resolvedSymbol(context, marketId: marketId)
        let leverage = context.leverage
        return PlannedClose(
            operationId: operationId,
            planned: planned,
            review: PerpsPlannerMapping.closeReview(
                review,
                symbol: symbol,
                feePpm: context.displayedTakerFeePpm(.close),
                leverage: leverage
            ),
            side: present.side,
            baseAmount: present.baseAmount
        )
    }

    func planSizeChange(
        _ intent: PerpsSizeChangeIntent,
        context: PerpsMarketContext,
        operationId: String = UUID().uuidString,
        normalizedAutoClose: PerpsAutoClose? = nil
    ) async throws -> PlannedSizeChange {
        guard let marginDelta = PerpsMarketMath.optionalDouble(intent.marginDeltaUsd), marginDelta > 0 else {
            throw PerpsTradingError.validation("amount is empty or invalid")
        }
        let present = try context.requirePosition()
        let now = PerpsPlannerMapping.nowUnixMs()
        let scale = context.rules.scale
        let closesWholePosition = intent.direction == .reduce && PerpsSizeChangeIntent.closesWholePosition(
            marginDeltaUsd: marginDelta,
            positionMarginUsd: PerpsScaled.double(present.allocatedMarginQuote, decimals: scale.quoteDecimals)
        )
        let clientOrderIndices = try await intents.clientOrderIndices(for: context)
        let legs = closesWholePosition ? PerpsAutoCloseLegs() : try intents.autoCloseLegs(
            intent.autoCloseUpdate,
            context: context,
            now: now,
            clientOrderIndices: clientOrderIndices
        )
        let chainIntent: PerpsTradeIntent
        switch intent.direction {
        case .add:
            let initialMarginBps = (context.accountSnapshot.marginSettings as? PerpsMarginSettings.Known)?
                .initialMarginBps ?? context.rules.minInitialMarginBps
            let marginQuote = try PerpsScaled.parse(intent.marginDeltaUsd, decimals: scale.quoteDecimals, rounding: .down)
            chainIntent = PerpsTradeIntent.Add(
                operationId: operationId,
                scope: context.scope,
                marketId: intent.marketId,
                positionId: present.positionId,
                side: present.side,
                marginBudgetQuote: marginQuote,
                initialMarginBps: initialMarginBps,
                clientOrderIndex: clientOrderIndices.order,
                order: PerpsOrderSpec.Market(
                    maxSlippagePpm: KotlinLong(value: PerpsPlannerMapping.slippagePpm(config.maxSlippage)),
                    slippageUtilizationPpm: 0,
                    marginSafetyBufferPpm: 0
                ),
                autoClose: legs.spec
            )
        case .reduce:
            guard present.allocatedMarginQuote > 0 else {
                throw PerpsTradingError.validation("amount exceeds position margin")
            }
            let closeBase: Int64?
            if closesWholePosition {
                closeBase = nil
            } else {
                let delta = try PerpsScaled.parse(intent.marginDeltaUsd, decimals: scale.quoteDecimals, rounding: .down)
                guard delta < present.allocatedMarginQuote else {
                    throw PerpsTradingError.validation("amount exceeds position margin")
                }
                let (product, overflow) = present.baseAmount.multipliedReportingOverflow(by: delta)
                guard !overflow else {
                    throw PerpsTradingError.validation("position size is too large")
                }
                let baseStep = max(context.rules.baseStep, 1)
                let partialBase = product / present.allocatedMarginQuote / baseStep * baseStep
                guard partialBase > 0 else {
                    throw PerpsTradingError.validation("amount is too small to reduce the position")
                }
                closeBase = partialBase
            }
            chainIntent = PerpsTradeIntent.Close(
                operationId: operationId,
                scope: context.scope,
                marketId: intent.marketId,
                positionId: present.positionId,
                side: present.side,
                positionBaseAmount: present.baseAmount,
                baseAmount: closeBase.map { KotlinLong(value: $0) },
                maxSlippagePpm: KotlinLong(value: PerpsPlannerMapping.slippagePpm(config.closeMaxSlippage)),
                clientOrderIndex: clientOrderIndices.order,
                autoClose: legs.spec
            )
        }
        let planned = try await host.plan(intent: chainIntent, context: context)
        let symbol = await resolvedSymbol(context, marketId: intent.marketId)
        let oldNotionalUsd = PerpsScaled.double(present.baseAmount, decimals: scale.baseDecimals)
            * PerpsScaled.double(present.entryPrice, decimals: scale.priceDecimals)
        let review: PerpsSizeChangeReview
        if let add = planned.plan.review as? PerpetualReview.Add {
            review = PerpsPlannerMapping.addReview(
                add,
                symbol: symbol,
                feePpm: context.displayedTakerFeePpm(.open),
                direction: .add,
                allocatedMarginBefore: present.allocatedMarginQuote,
                oldBase: present.baseAmount,
                oldEntry: present.entryPrice,
                oldNotionalUsd: oldNotionalUsd,
                liquidationBefore: present.liquidationPrice?.int64Value
            )
        } else if let close = planned.plan.review as? PerpetualReview.Close {
            review = PerpsPlannerMapping.closeSizeReview(
                close,
                symbol: symbol,
                feePpm: context.displayedTakerFeePpm(.close),
                direction: .reduce,
                marginDeltaUsd: marginDelta,
                leverage: context.leverage,
                oldBase: present.baseAmount,
                oldEntry: present.entryPrice,
                oldNotionalUsd: oldNotionalUsd,
                liquidationBefore: present.liquidationPrice?.int64Value
            )
        } else {
            throw PerpsTradingError.protocolFailure("unexpected size-change review")
        }
        return PlannedSizeChange(
            operationId: operationId,
            planned: planned,
            review: review,
            side: present.side,
            baseAmount: present.baseAmount,
            normalizedAutoClose: normalizedAutoClose ?? legs.target,
            pendingAutoClose: legs.pending
        )
    }

    func planMarginChange(
        _ intent: PerpsMarginChangeIntent,
        context: PerpsMarketContext,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedMarginChange {
        guard let amount = PerpsMarketMath.optionalDouble(intent.amountUsd), amount > 0 else {
            throw PerpsTradingError.validation("amount is empty or invalid")
        }
        let present = try context.requirePosition()
        let chainIntent = try intents.margin(
            intent,
            context: context,
            present: present,
            operationId: operationId
        )
        let planned = try await host.plan(intent: chainIntent, context: context)
        guard let review = planned.plan.review as? PerpetualReview.Margin else {
            throw PerpsTradingError.protocolFailure("unexpected margin review")
        }
        let mapped = PerpsPlannerMapping.marginReview(
            review,
            symbol: await resolvedSymbol(context, marketId: intent.marketId),
            direction: intent.direction,
            side: PerpsPlannerMapping.tradeSide(present.side),
            leverage: context.leverage,
            allocatedBefore: present.allocatedMarginQuote,
            liquidationBefore: present.liquidationPrice?.int64Value
        )
        return PlannedMarginChange(
            operationId: operationId,
            planned: planned,
            review: mapped,
            side: present.side,
            allocatedBefore: present.allocatedMarginQuote,
            amount: amount,
            isImmediateRisk: mapped.isImmediateRisk
        )
    }

    func planAutoCloseChange(
        _ intent: PerpsAutoCloseChangeIntent,
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedAutoClose {
        let context = try await marketContext(session: session, marketId: intent.marketId)
        let present = try context.requirePosition()
        let legs = try await intents.autoCloseLegs(
            intent.renewsExpiry
                ? .replace(intent.target)
                : PerpsAutoCloseUpdate(
                    desired: intent.target,
                    resting: PerpsAutoClose(triggerOrders: intents.restingTriggerOrders(context))
                ),
            context: context,
            now: PerpsPlannerMapping.nowUnixMs(),
            clientOrderIndices: intents.clientOrderIndices(for: context),
            renewsExpiry: intent.renewsExpiry
        )
        guard let pending = legs.pending else {
            throw context.accountSnapshot.completeness is PerpsContextCompleteness.Incomplete
                ? PerpsTradingError.tradingUnavailable
                : PerpsTradingError.nothingToChange
        }
        let chainIntent = PerpsTradeIntent.AutoClose(
            operationId: operationId,
            scope: context.scope,
            marketId: intent.marketId,
            positionId: present.positionId,
            side: present.side,
            autoClose: legs.spec
        )
        let planned = try await host.plan(intent: chainIntent, context: context)
        guard let review = planned.plan.review as? PerpetualReview.AutoClose else {
            throw PerpsTradingError.protocolFailure("unexpected auto-close review")
        }
        return PlannedAutoClose(
            operationId: operationId,
            planned: planned,
            review: PerpsPlannerMapping.autoCloseReview(review, scale: context.rules.scale),
            cancelIndexes: pending.restingOrderIndexes
        )
    }

    func planLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent,
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedLimitChange {
        let screen = try await loadTradingScreen(marketId: intent.marketId)
        let ordersReadable = PerpsBackendMapping.ordersReadable(screen)
        let resting = ordersReadable
            ? PerpsBackendMapping.limitOrders(screen.open_orders).first { $0.orderIndex == intent.orderIndex }
            ?? (intent.kind == .cancel ? PerpsBackendMapping.autoCloseLeg(screen.open_orders, key: intent.orderIndex) : nil)
            : nil
        let order: PerpsLimitOrderSummary
        var confirmedScreen: Components.Schemas.TradingScreen?
        switch (resting, intent, ordersReadable) {
        case let (.some(value), _, _):
            order = value
        case (.none, _, false):
            throw PerpsTradingError.tradingUnavailable
        case (.none, .cancel, true) where intent.orderId.isEmpty:
            throw PerpsTradingError.nothingToChange
        case (.none, _, true):
            let detail: Components.Schemas.OrderDetail?
            do {
                detail = try await perpsAPI.getOrder(walletId: requireWalletId(), id: intent.orderId)
            } catch PerpsAPIError.notFound {
                detail = nil
            }
            order = try PerpsBackendMapping.changeTarget(detail, kind: intent.kind)
            confirmedScreen = screen
            confirmedScreen?.open_orders = (screen.open_orders ?? []) + (detail?.order.map { [$0] } ?? [])
        }
        let context = try await marketContext(
            session: session,
            marketId: intent.marketId,
            preRead: confirmedScreen.map { confirmed in Task { confirmed } }
        )
        let chainIntent: PerpsTradeIntent
        let normalizedPrice: Double?
        switch intent {
        case let .modify(_, _, limitPrice, seenBaseAmount, _):
            let scale = context.rules.scale
            let scaled = try PerpsScaled.scale(limitPrice, decimals: scale.priceDecimals, rounding: .nearest)
            guard let resting = context.accountSnapshot.restingOrders.first(where: { $0.orderIndex == intent.orderIndex }) else {
                throw PerpsTradingError.orderNotFound
            }
            let remaining = resting.remainingBaseAmount
            let seen = try PerpsScaled.scale(seenBaseAmount, decimals: scale.baseDecimals, rounding: .nearest)
            guard remaining <= seen else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            chainIntent = PerpsTradeIntent.OrderModify(
                operationId: operationId,
                scope: context.scope,
                marketId: intent.marketId,
                orderIndex: intent.orderIndex,
                baseAmount: remaining,
                price: scaled,
                triggerPrice: nil
            )
            let planned = try await host.plan(intent: chainIntent, context: context)
            guard let review = planned.plan.review as? PerpetualReview.OrderModify else {
                throw PerpsTradingError.protocolFailure("unexpected modify review")
            }
            normalizedPrice = PerpsScaled.double(review.price, decimals: scale.priceDecimals)
            guard let price = normalizedPrice,
                  !PerpsLimitOrderChangeSettlement.pricesMatch(price, order.limitPrice)
            else {
                throw PerpsTradingError.nothingToChange
            }
            return PlannedLimitChange(
                operationId: operationId,
                planned: planned,
                review: PerpsLimitOrderChangeReview(
                    order: order,
                    kind: .modify,
                    limitPrice: normalizedPrice,
                    baseAmount: PerpsScaled.double(remaining, decimals: scale.baseDecimals)
                )
            )
        case .cancel:
            chainIntent = PerpsTradeIntent.OrderCancel(
                operationId: operationId,
                scope: context.scope,
                marketId: intent.marketId,
                orderIndex: intent.orderIndex
            )
            normalizedPrice = nil
        }
        return try PlannedLimitChange(
            operationId: operationId,
            planned: await host.plan(intent: chainIntent, context: context),
            review: PerpsLimitOrderChangeReview(
                order: order,
                kind: intent.kind,
                limitPrice: normalizedPrice,
                baseAmount: order.remainingBaseAmount
            )
        )
    }

    func pending(
        _ prepared: some PerpsPreparedAction,
        side: PerpsTradeSide,
        payload: PerpsPendingPayload,
        expectedBaseSize: Double? = nil,
        positionBaseSizeBefore: Double? = nil
    ) -> PerpsPendingTradingAction {
        PerpsPendingTradingAction(
            operationId: prepared.operationId,
            walletId: prepared.walletId,
            marketId: prepared.marketId,
            side: side,
            payload: payload,
            expiresAtMillis: payload.leavesRestingOrder
                ? intents.orderExpiryUnixMs(now: PerpsPlannerMapping.nowUnixMs())
                : nil,
            expectedBaseSize: expectedBaseSize,
            positionBaseSizeBefore: positionBaseSizeBefore
        )
    }

    /// What the renewal may sign again: the TP/SL prices this device signs. The renewal acts
    /// only while the venue holds the same prices.
    func confirmAutoClose(
        marketId: Int64,
        _ update: @escaping @Sendable (_ current: PerpsAutoClose?) -> PerpsAutoClose?
    ) async {
        do {
            try await journal.confirmAutoClose(marketId: marketId, update)
        } catch {
            PerpsOperationLog.event("auto_close_confirmed", outcome: "failed", error: error, fields: ["market_id": String(marketId)])
        }
    }

    func submitAction(
        _ prepared: some PerpsPreparedAction,
        inProgress: PerpsTradeInProgress?,
        passcodeProvider: () async -> String?,
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult {
        return await PerpsOperationLog.withContext(fields: prepared.operationLogFields.merging(["trace_id": prepared.operationId]) { _, new in new }) {
            guard wallet.id == prepared.walletId else {
                PerpsOperationLog.event("submit", outcome: "rejected", source: "wallet", error: PerpsTradingError.stalePreparedTransaction)
                return .failed(.stalePreparedTransaction)
            }
            if let inProgress {
                tradeBegan(prepared.operationId, prepared.marketId, inProgress)
            }
            PerpsOperationLog.event("submit", outcome: "started")
            let result = await submitSigned(prepared, passcodeProvider: passcodeProvider, build: build)
            switch result {
            case let .submitted(pending):
                PerpsOperationLog.event("submit", outcome: "accepted", source: "lighter", fields: pending.operationLogFields)
            case let .submitUnknown(pending):
                PerpsOperationLog.event("submit", outcome: "unknown", source: "unknown", fields: pending.operationLogFields)
            case let .failed(error):
                PerpsOperationLog.event("submit", outcome: "failed", error: error)
            }
            if case .failed = result {
                tradeSettled(prepared.operationId, false)
            }
            return result
        }
    }

    private func submitSigned(
        _ prepared: some PerpsPreparedAction,
        passcodeProvider: () async -> String?,
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult {
        let marketId = prepared.marketId
        defer {
            tradingScreenReads.invalidate()
            if let walletId = try? requireWalletId() {
                accountService.integratorReads.invalidate(walletId: walletId)
            }
        }
        let session: PerpsAccountSession
        do {
            guard let resolved = try await accountService.tradingSession(wallet: wallet) else {
                return .failed(.activationRequired)
            }
            session = resolved
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            PerpsOperationLog.event("session", outcome: "failed", source: "wallet", error: error, fields: mapped.operationLogFields)
            return .failed(mapped)
        }
        await accountService.ensurePlusTier(wallet: wallet, trigger: .trade, readOnlyToken: readOnlyToken)

        let lane = await accountService.submitLanes.lane(for: session)
        if let result = await submitPass(prepared, session: session, lane: lane, passcodeProvider: passcodeProvider, build: build) {
            return result
        }
        // The approval this device recorded no longer holds on Lighter: it is signed again and
        // the operation repeated once, on a fresh integrator read.
        if let walletId = try? requireWalletId() {
            accountService.integratorReads.invalidate(walletId: walletId)
        }
        return await submitPass(prepared, session: session, lane: lane, passcodeProvider: passcodeProvider, build: build)
            ?? .failed(.serverRejected("integrator not approved"))
    }

    private func submitPass(
        _ prepared: some PerpsPreparedAction,
        session: PerpsAccountSession,
        lane: PerpsSubmitLane,
        passcodeProvider: () async -> String?,
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult? {
        let operationId = prepared.operationId
        let marketId = prepared.marketId
        let approval: PerpsPreparedIntegratorApproval?
        do {
            approval = try await accountService.prepareIntegratorApproval(
                wallet: wallet,
                session: session,
                passcodeProvider: passcodeProvider
            )
        } catch {
            return .failed(integratorApprovalFailure(error))
        }

        // A plan is validated against the read it was built from, so planning belongs in
        // the same lane as the signing it feeds: two operations that both plan before
        // either one sends would each build on the state before the other's orders.
        do {
            return try await lane.run {
                do {
                    // Only an unfinished operation that could still place an order on
                    // this market can interfere with this one. Anything else — another
                    // market, a margin move, a resting-order edit — is recovered in the
                    // same pass and holds nothing back here.
                    if try await recoverLocalPendingInLane(excluding: operationId, lane: lane).contains(marketId) {
                        PerpsOperationLog.event("submit", outcome: "blocked", fields: ["market_id": String(marketId), "reason": "unresolved_pending"])
                        return .failed(.operationInProgress)
                    }
                } catch {
                    let mapped = PerpsTradingErrorMapper.map(error)
                    PerpsOperationLog.event("recovery_before_submit", outcome: "failed", error: error, fields: mapped.operationLogFields)
                    return .failed(mapped)
                }
                if let approval {
                    do {
                        try await accountService.submitIntegratorApproval(approval, wallet: wallet, session: session, lane: lane)
                    } catch {
                        return .failed(integratorApprovalFailure(error))
                    }
                }
                return await submitInLane(session: session, lane: lane, build: build)
            }
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            PerpsOperationLog.event("submit_lane", outcome: "failed", source: mapped.operationLogSource, error: error, fields: mapped.operationLogFields)
            return .failed(error is CancellationError ? .operationInProgress : mapped)
        }
    }

    private func integratorApprovalFailure(_ error: Error) -> PerpsTradingError {
        let mapped = PerpsTradingErrorMapper.map(error)
        PerpsOperationLog.event("integrator_approval", outcome: "failed", source: mapped.operationLogSource, error: error, fields: mapped.operationLogFields)
        return mapped
    }

    /// Nil when an integrator refusal can be recovered by approving and rebuilding the operation.
    private func submitInLane(
        session: PerpsAccountSession,
        lane: PerpsSubmitLane,
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult? {
        async let nonceCaughtUp: Void = catchUpNonce(lane: lane)
        let submission: Submission
        do {
            submission = try await build(session)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            PerpsOperationLog.event("submit_prepare", outcome: "failed", source: mapped.operationLogSource, error: error, fields: mapped.operationLogFields)
            return .failed(mapped)
        }

        let pending: PerpsPendingTradingAction
        do {
            let result = try await journal.savePendingIfAbsentWithStatus(submission.pending)
            guard result.inserted else {
                PerpsOperationLog.event("submit", outcome: "blocked", fields: result.pending.operationLogFields.merging(["reason": "duplicate_operation"]) { _, new in new })
                return .failed(.operationInProgress)
            }
            pending = result.pending
            operationJournaled()
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            PerpsOperationLog.event("journal", outcome: "failed", error: error, fields: mapped.operationLogFields)
            return .failed(mapped)
        }

        PerpsOperationLog.event("execute", outcome: "started", fields: pending.operationLogFields)
        var orderRefs = [PerpsPendingOrderRef]()
        var signedSteps = [PerpsPendingSignedStep]()
        func journaled() -> PerpsPendingTradingAction {
            var value = pending
            if !orderRefs.isEmpty { value.orderRefs = orderRefs }
            if !signedSteps.isEmpty { value.signedSteps = signedSteps }
            return value
        }
        let execution = PerpsExecutionRelay(
            lane: lane,
            persistState: { [journal] signed, state in
                let refs = PerpsPlannerMapping.orderRefs(signed)
                for ref in refs where !orderRefs.contains(ref) {
                    orderRefs.append(ref)
                }
                let persisted = PerpsPendingSignedStep(
                    stepId: signed.stepId,
                    attemptId: signed.attemptId,
                    nonce: signed.nonce,
                    transactionExpiryUnixMs: signed.transactionExpiryUnixMs,
                    txType: signed.txType,
                    txInfo: signed.txInfo,
                    txHash: signed.txHash,
                    state: state
                )
                if state == .signed {
                    PerpsOperationLog.event("sign", outcome: "signed", source: "wallet", fields: ["operation_id": pending.operationId, "step_id": signed.stepId, "attempt_id": signed.attemptId, "nonce": String(signed.nonce), "tx_type": String(signed.txType), "tx_hash": signed.txHash, "expires_at_ms": String(signed.transactionExpiryUnixMs)])
                } else if state == .unknown {
                    PerpsOperationLog.event("send", outcome: "unknown", source: "unknown", fields: ["operation_id": pending.operationId, "step_id": signed.stepId, "tx_hash": signed.txHash])
                }
                if let index = signedSteps.firstIndex(where: { $0.stepId == persisted.stepId }) {
                    signedSteps[index] = persisted
                } else {
                    signedSteps.append(persisted)
                }
                try await journal.appendSignedStep(
                    operationId: pending.operationId,
                    step: persisted,
                    refs: refs,
                    followUps: refs.contains { $0.role == .parent || $0.role == .add } ? submission.followUps : []
                )
            }
        )
        await nonceCaughtUp
        do {
            try await submission.execute(execution)
            PerpsOperationLog.event("execute", outcome: "accepted", source: "lighter", fields: pending.operationLogFields)
            return .submitted(journaled())
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            PerpsOperationLog.event("execute", outcome: signedSteps.isEmpty ? "failed" : "unknown", source: mapped.operationLogSource, error: error, fields: mapped.operationLogFields.merging(journaled().operationLogFields) { _, new in new })
            if execution.integratorNotApproved {
                accountService.forgetIntegratorApproval(wallet: wallet)
                // Leverage is an idempotent setting; accepted orders and margin moves must not be repeated.
                if Self.onlyLeverageLanded(signedSteps),
                   (try? await journal.removePending(operationId: pending.operationId, includingFollowUps: true)) != nil
                {
                    PerpsOperationLog.event("integrator_approval", outcome: "retry", fields: pending.operationLogFields)
                    return nil
                }
            }
            if execution.sendRefused, Self.onlyLeverageLanded(signedSteps),
               (try? await journal.removePending(operationId: pending.operationId, includingFollowUps: true)) != nil
            {
                PerpsOperationLog.event("execute", outcome: "refused", source: mapped.operationLogSource, fields: pending.operationLogFields)
                return .failed(mapped)
            }
            if case .offline = mapped {
                return .submitUnknown(journaled())
            }
            if case .timeout = mapped {
                return .submitUnknown(journaled())
            }
            if case .serverUnavailable = mapped {
                return .submitUnknown(journaled())
            }
            if case .unknown = mapped {
                return .submitUnknown(journaled())
            }
            if !signedSteps.isEmpty {
                return .submitUnknown(journaled())
            }
            if !orderRefs.isEmpty {
                return .submitUnknown(journaled())
            }
            try? await journal.removePending(operationId: pending.operationId)
            return .failed(mapped)
        }
    }

    private func catchUpNonce(lane: PerpsSubmitLane) async {
        guard let walletId = try? requireWalletId() else { return }
        await lane.catchUpNonce(walletId: walletId)
    }

    func reconcileByState(
        _ pending: PerpsPendingTradingAction,
        label: String,
        decide: (Components.Schemas.PositionState) async -> PerpsTkReconcile.Decision
    ) async -> PerpsReconcileResult {
        guard wallet.id == pending.walletId else { return .pending }
        return await settle(pending, label: label) {
            // Without the exact client order key, a position snapshot cannot answer
            // this operation. Reading the unfiltered snapshot would accept a sibling
            // order from the same market as proof that this one filled.
            guard let ref = pending.positionOrderRef else {
                let decision = PerpsTkReconcile.withoutOrderKey(pending, now: PerpsServerClock.shared.signingNowUnixMs())
                if decision == .notSubmitted {
                    PerpsOperationLog.event("reconcile", outcome: "unavailable", fields: pending.operationLogFields.merging(["reason": "order_key_missing"]) { _, new in new })
                }
                return decision
            }
            let state = try await loadPositionState(marketId: pending.marketId, clientOrderIndex: ref.clientOrderIndex)
            let decision = await PerpsTkReconcile.withOrderKey(
                decide(state),
                orders: state.orders,
                pending: pending,
                now: PerpsServerClock.shared.signingNowUnixMs()
            )
            if decision == .notSubmitted {
                PerpsOperationLog.event("reconcile", outcome: "not_submitted", fields: pending.operationLogFields)
            }
            return decision
        }
    }

    /// The one place a reconciliation decision turns into a result: a settled pending
    /// leaves the journal, a refusal is reported, and a read that failed is simply not
    /// an answer yet.
    func settle(
        _ pending: PerpsPendingTradingAction,
        label: String,
        decide: () async throws -> PerpsTkReconcile.Decision
    ) async -> PerpsReconcileResult {
        let fields = pending.operationLogFields.merging(["reconcile_target": label]) { _, new in new }
        do {
            switch try await decide() {
            case .confirmed:
                await resolveSettled(pending, succeeded: true)
                PerpsOperationLog.event("reconcile", outcome: "confirmed", source: "lighter", fields: fields)
                return .confirmed
            case .partiallyFilled:
                await resolveSettled(pending, succeeded: true)
                PerpsOperationLog.event("reconcile", outcome: "partially_filled", source: "lighter", fields: fields)
                return .partiallyFilled
            case let .failed(message):
                await resolveSettled(pending, succeeded: false)
                PerpsOperationLog.event("reconcile", outcome: "rejected", source: "lighter", fields: fields.merging(["reason": message]) { _, new in new })
                return .failed(PerpsBackendMapping.rejectionError(message))
            case .notSubmitted:
                await resolveSettled(pending, succeeded: false)
                PerpsOperationLog.event("reconcile", outcome: "not_submitted", fields: fields)
                return .failed(.stalePreparedTransaction)
            case .pending:
                return .pending
            }
        } catch {
            PerpsOperationLog.event("reconcile", outcome: "unavailable", source: "backend", error: error, fields: fields)
            return .pending
        }
    }

    func loadAccountSnapshot() async throws -> PerpsAccountSnapshot {
        let portfolio = try await perpsAPI.portfolio(walletId: requireWalletId())
        return PerpsBackendMapping.snapshot(
            availableBalance: portfolio.balance?.available_balance ?? "0",
            collateral: portfolio.balance?.collateral,
            equity: portfolio.balance?.equity,
            positions: portfolio.positions
        )
    }

    func loadTradingScreen(marketId: Int64) async throws -> Components.Schemas.TradingScreen {
        let walletId = try requireWalletId()
        return try await PerpsAPIError.reissuingReadOnlyToken({ await readOnlyToken.issue() }) {
            try await perpsAPI.tradingScreen(walletId: walletId, marketId: marketId)
        }
    }

    func loadOpenPositionDetail(marketId: Int64) async throws -> Components.Schemas.OpenPositionDetail? {
        do {
            return try await perpsAPI.getOpenPosition(
                walletId: requireWalletId(),
                id: PerpsPlannerMapping.tkPositionId(marketId: marketId)
            )
        } catch PerpsAPIError.notFound {
            return nil
        }
    }

    func loadPositionState(
        marketId: Int64,
        clientOrderIndex: Int64?
    ) async throws -> Components.Schemas.PositionState {
        return try await perpsAPI.positionState(
            walletId: requireWalletId(),
            id: PerpsPlannerMapping.tkPositionId(marketId: marketId),
            clientOrderIndex: clientOrderIndex
        )
    }

    /// Announced before the entry leaves the journal, so a reader that finds it gone
    /// already has the verdict the journal no longer keeps.
    func resolveSettled(_ pending: PerpsPendingTradingAction, succeeded: Bool) async {
        NotificationCenter.default.post(
            name: .perpsTradingOperationSettled,
            object: PerpsTradingSettlement(action: pending, succeeded: succeeded)
        )
        tradeSettled(pending.operationId, succeeded)
        try? await journal.removePending(operationId: pending.operationId, includingFollowUps: !succeeded)
    }

    /// Recovers every pending this wallet holds and answers with the markets whose
    /// own pending is still unresolved.
    private func recoverLocalPendingInLane(excluding operationId: String?, lane: PerpsSubmitLane) async throws -> Set<Int64> {
        return try await PerpsOperationLog.step("recovery", fields: ["flow": "trade", "wallet_id": format2WalletId() ?? wallet.id], quiet: true) {
            try Task.checkCancellation()
            try await journal.cleanupPending()
            let pendings = try await journal.allPending()
            var unresolved = Set<Int64>()
            let signingNow = PerpsServerClock.shared.signingNowUnixMs()
            for pending in pendings where pending.operationId != operationId {
                try Task.checkCancellation()
                if case .autoCloseRebase = pending.payload {
                    // Its entry may have settled earlier in this pass, stamping or dropping it.
                    if let current = try? await journal.pending(operationId: pending.operationId),
                       case let .autoCloseRebase(rebase) = current.payload
                    {
                        await PerpsOperationLog.withContext(fields: current.operationLogFields) {
                            await recoverAutoCloseRebase(current, rebase: rebase, lane: lane)
                        }
                    }
                    continue
                }
                PerpsOperationLog.event("recovery", outcome: "checking", fields: pending.operationLogFields.merging(["blocks_position_orders": String(pending.blocksPositionOrders(now: signingNow))]) { _, new in new })
                if let interrupted = PerpsTkReconcile.interruptedSend(pending) {
                    // SENDING is the crash window: the request may already have reached
                    // the venue, so recovery must reconcile it, never send it again.
                    try? await journal.appendSignedStep(
                        operationId: pending.operationId,
                        step: interrupted,
                        refs: pending.orderRefs ?? []
                    )
                }
                if let signed = PerpsTkReconcile.unsentStep(pending) {
                    do {
                        let walletId = try requireWalletId()
                        try Task.checkCancellation()
                        try await journal.appendSignedStep(
                            operationId: pending.operationId,
                            step: signed.withState(.sending),
                            refs: pending.orderRefs ?? []
                        )
                        try Task.checkCancellation()
                        try await PerpsOperationLog.withContext(fields: pending.operationLogFields) {
                            try await lane.send(
                                walletId: walletId,
                                txType: signed.txType,
                                txInfo: signed.txInfo,
                                txHash: signed.txHash,
                                nonce: signed.nonce
                            )
                        }
                        try await journal.appendSignedStep(
                            operationId: pending.operationId,
                            step: signed.withState(.accepted),
                            refs: pending.orderRefs ?? []
                        )
                    } catch {
                        let mapped = PerpsTradingErrorMapper.map(error)
                        if PerpsTkReconcile.refusedSendSettles(mapped, pending: pending) {
                            PerpsOperationLog.event("recovery_send", outcome: "rejected", source: mapped.operationLogSource, error: error, fields: pending.operationLogFields)
                            await resolveSettled(pending, succeeded: false)
                            continue
                        }
                        PerpsOperationLog.event("recovery_send", outcome: "unknown", source: mapped.operationLogSource, error: error, fields: pending.operationLogFields)
                        try? await journal.appendSignedStep(
                            operationId: pending.operationId,
                            step: signed.withState(.unknown),
                            refs: pending.orderRefs ?? []
                        )
                        if pending.blocksPositionOrders(now: signingNow) {
                            unresolved.insert(pending.marketId)
                        }
                        continue
                    }
                }
                let current = (try? await journal.pending(operationId: pending.operationId)) ?? pending
                if await reconcilePersisted(current) == false, current.blocksPositionOrders(now: signingNow) {
                    unresolved.insert(pending.marketId)
                }
            }
            return unresolved
        }
    }

    func reconcilePersisted(_ pending: PerpsPendingTradingAction) async -> Bool {
        switch await reconcile(pending) {
        case .confirmed, .partiallyFilled, .failed: return true
        case .pending: return false
        }
    }
}

private extension PerpsTkTradingService {
    func recoverAutoCloseRebase(
        _ pending: PerpsPendingTradingAction,
        rebase: PerpsPendingAutoCloseRebase,
        lane: PerpsSubmitLane
    ) async {
        func finish(_ reason: String) async throws {
            PerpsOperationLog.event("auto_close_rebase", outcome: "finished", fields: pending.operationLogFields.merging(["reason": reason]) { _, new in new })
            try await journal.removePending(operationId: pending.operationId)
        }
        do {
            let now = PerpsPlannerMapping.nowUnixMs()
            guard let expiry = pending.expiresAtMillis, now < expiry else {
                try await finish("expired")
                return
            }
            guard let ref = pending.triggerOrderRefs.first else {
                try await finish("missing trigger identity")
                return
            }
            func recordMoved(_ price: Double) async {
                let moved = PerpsAutoCloseTrigger(triggerPrice: price)
                await confirmAutoClose(marketId: pending.marketId) { signed in
                    PerpsAutoClose(
                        takeProfit: ref.role == .takeProfit ? moved : signed?.takeProfit,
                        stopLoss: ref.role == .stopLoss ? moved : signed?.stopLoss
                    )
                }
            }
            guard try await journal.pending(operationId: rebase.parentOperationId) == nil else { return }
            /// The venue shows a fill, its legs and the position one read at a time; a state that
            /// has not caught up yet gets a short grace before the legs are left as they are.
            func waitForVenue(_ reason: String) async throws {
                let since = rebase.entrySettledAtMillis ?? pending.createdAtMillis
                guard now - since > PerpsAutoCloseRebase.settleWindowMillis else { return }
                try await finish(reason)
            }
            let state = try await loadPositionState(marketId: pending.marketId, clientOrderIndex: rebase.parentClientOrderIndex)
            guard Set(state.orders.map(\.order_index)).count <= 1 else {
                try await finish("entry client index names several orders")
                return
            }
            guard let filled = PerpsAutoCloseRebase.finalFilledBase(state.orders) else {
                try await waitForVenue("entry still working")
                return
            }
            guard filled > 0 else {
                try await finish("entry never filled")
                return
            }
            let session = try await requireSession()
            let context = try await marketContext(session: session, marketId: pending.marketId)
            guard !(context.accountSnapshot.completeness is PerpsContextCompleteness.Incomplete) else {
                try await waitForVenue("orders still unreadable")
                return
            }
            let category: PerpsOrderCategory = ref.role == .takeProfit ? .takeprofit : .stoploss
            guard let order = context.accountSnapshot.restingOrders.first(where: {
                $0.clientOrderIndex?.int64Value == ref.clientOrderIndex && $0.category == category
            }), order.positionTied, order.reduceOnly,
            let originalTrigger = order.triggerPrice?.int64Value else {
                try await waitForVenue("original protection not resting")
                return
            }
            let decimals = context.rules.scale.priceDecimals
            let restingPrice = PerpsScaled.double(originalTrigger, decimals: decimals)
            if let target = rebase.targetPrice,
               PerpsLimitOrderChangeSettlement.pricesMatch(restingPrice, target)
            {
                await recordMoved(target)
                try await finish("target confirmed")
                return
            }
            guard PerpsLimitOrderChangeSettlement.pricesMatch(restingPrice, rebase.originalTriggerPrice) else {
                try await finish("trigger changed elsewhere")
                return
            }
            if let signed = pending.signedSteps?.first {
                guard PerpsServerClock.shared.signingNowUnixMs(deviceNowUnixMs: now) <= signed.transactionExpiryUnixMs else {
                    try await finish("signed correction expired; retaining current protection")
                    return
                }
                // Once sending started its outcome may be unknown. Never sign or replay it again.
                guard signed.state == .signed else { return }
            }
            let baseDecimals = context.rules.scale.baseDecimals
            let expectedBase = try PerpsScaled.scale(rebase.positionBaseBefore ?? 0, decimals: baseDecimals, rounding: .nearest)
                + PerpsScaled.scale(filled, decimals: baseDecimals, rounding: .nearest)
            // Only a position made of exactly this entry has the entry's average as its own.
            guard let position = context.accountSnapshot.position as? PerpsPositionState.Present,
                  PerpsPlannerMapping.tradeSide(position.side) == pending.side,
                  position.baseAmount == expectedBase,
                  let margin = context.accountSnapshot.marginSettings as? PerpsMarginSettings.Known,
                  margin.initialMarginBps == PerpsPlannerMapping.initialMarginBps(leverage: rebase.leverage),
                  let entryPrice = context.entryPrice
            else {
                try await waitForVenue("position does not show this entry")
                return
            }
            let trigger = try PerpsAutoCloseRebase.targetPrice(
                rebase, side: pending.side,
                entryPrice: entryPrice,
                priceDecimals: decimals, tick: context.rules.priceTick
            )
            let target = PerpsScaled.double(trigger, decimals: decimals)
            guard PerpsReviewDrift.near(rebase.originalTriggerPrice, target) else {
                try await finish("entry moves the trigger past the confirmed one")
                return
            }
            if let frozen = rebase.targetPrice, !PerpsLimitOrderChangeSettlement.pricesMatch(target, frozen) {
                try await finish("entry changed after correction was prepared")
                return
            }
            if PerpsLimitOrderChangeSettlement.pricesMatch(target, restingPrice) {
                try await finish("already at requested ROI")
                return
            }
            // Quote protection with an unused index; only its bound feeds the in-place modify.
            let quoteIndex = try await intents.clientOrderIndices(for: context).takeProfit
            let leg = PerpsAutoCloseLeg(
                triggerPrice: trigger, maxSlippagePpm: nil,
                expiryUnixMs: order.expiryUnixMs?.int64Value ?? expiry,
                clientOrderIndex: quoteIndex
            )
            let protection = PerpsTradeIntent.AutoClose(
                operationId: pending.operationId, scope: context.scope, marketId: pending.marketId,
                positionId: position.positionId, side: position.side,
                autoClose: PerpsAutoCloseSpec(
                    takeProfit: ref.role == .takeProfit ? leg : nil,
                    stopLoss: ref.role == .stopLoss ? leg : nil,
                    replacedTakeProfitOrderIndex: nil, replacedStopLossOrderIndex: nil
                )
            )
            let protectionPlan = try await host.plan(intent: protection, context: context)
            guard let review = protectionPlan.plan.review as? PerpetualReview.AutoClose,
                  let bound = ref.role == .takeProfit ? review.takeProfitLimit : review.stopLossLimit
            else {
                throw PerpsTradingError.protocolFailure("missing protective bound")
            }
            if let signed = pending.signedSteps?.first {
                try Task.checkCancellation()
                try await journal.appendSignedStep(operationId: pending.operationId, step: signed.withState(.sending), refs: [])
                try await lane.send(walletId: requireWalletId(), txType: signed.txType, txInfo: signed.txInfo, txHash: signed.txHash, nonce: signed.nonce)
                try await journal.appendSignedStep(operationId: pending.operationId, step: signed.withState(.accepted), refs: [])
                await recordMoved(target)
                return
            }
            let modify = PerpsTradeIntent.OrderModify(
                operationId: pending.operationId, scope: context.scope, marketId: pending.marketId,
                orderIndex: ref.clientOrderIndex, baseAmount: LighterConstants.shared.NilOrderBaseAmount,
                price: bound.int64Value, triggerPrice: KotlinLong(value: trigger)
            )
            let planned = try await host.plan(intent: modify, context: protectionPlan.context.withMarketSnapshot(protectionPlan.marketSnapshot))
            try await journal.setRebaseTarget(operationId: pending.operationId, price: target)
            let execution = PerpsExecutionRelay(lane: lane, persistState: { [journal] signed, state in
                try await journal.appendSignedStep(
                    operationId: pending.operationId,
                    step: PerpsPendingSignedStep(
                        stepId: signed.stepId, attemptId: signed.attemptId, nonce: signed.nonce,
                        transactionExpiryUnixMs: signed.transactionExpiryUnixMs, txType: signed.txType,
                        txInfo: signed.txInfo, txHash: signed.txHash, state: state
                    ),
                    refs: []
                )
            })
            try Task.checkCancellation()
            try await host.execute(planned: planned, signingKey: await signingKey(accountIndex: session.accountIndex), execution: execution)
            await recordMoved(target)
            PerpsOperationLog.event("auto_close_rebase", outcome: "accepted", source: "lighter", fields: pending.operationLogFields.merging(["trigger_price": String(target)]) { _, new in new })
        } catch is CancellationError {
            return
        } catch let refusal as PerpsSignedMarketRefusal {
            PerpsOperationLog.event("auto_close_rebase", outcome: "paused", source: refusal.error.operationLogSource, error: refusal, fields: pending.operationLogFields.merging(refusal.error.operationLogFields) { _, new in new })
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            switch mapped {
            case .invalidAutoClose, .validation, .orderNotFound, .nothingToChange, .positionNotFound, .immediateLiquidationRisk:
                try? await finish("correction no longer admissible: \(mapped)")
            default:
                PerpsOperationLog.event("auto_close_rebase", outcome: "paused", source: mapped.operationLogSource, error: error, fields: pending.operationLogFields.merging(mapped.operationLogFields) { _, new in new })
            }
        }
    }
}

extension PerpsTkTradingService {
    static func onlyLeverageLanded(_ steps: [PerpsPendingSignedStep]) -> Bool {
        steps.allSatisfy { $0.state != .accepted || $0.txType == LighterConstants.shared.TxTypeL2UpdateLeverage }
    }
}
