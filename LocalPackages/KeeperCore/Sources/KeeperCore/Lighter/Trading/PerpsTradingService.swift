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
    private let perpsAPI: PerpsAPI
    private let markPriceProvider: @Sendable (Int64) async -> Double?
    private let marketProvider: @Sendable (Int64) async -> PerpsMarketMetadata?
    private let config: PerpsTradingConfig
    private let intents: PerpsChainIntents
    private let host: PerpsPlannerHost
    private let nonceCoordinator: PerpsNonceCoordinator
    private let autoCloseRenewalLock = NSLock()
    private var autoCloseRenewalCheckedAt: Date?

    static let autoCloseRenewalLeadSeconds: Int64 = 7 * 24 * 60 * 60
    static let autoCloseRenewalCheckInterval: TimeInterval = 60 * 60

    init(
        accountService: PerpsAccountService,
        wallet: Wallet,
        perpsAPI: PerpsAPI,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?,
        config: PerpsTradingConfig = PerpsTradingConfig(),
        nonceCoordinator: PerpsNonceCoordinator = .shared
    ) {
        self.accountService = accountService
        self.wallet = wallet
        self.perpsAPI = perpsAPI
        self.markPriceProvider = markPriceProvider
        self.marketProvider = marketProvider
        self.config = config
        intents = PerpsChainIntents(config: config)
        self.nonceCoordinator = nonceCoordinator
        host = PerpsPlannerHost(api: perpsAPI, nonceCoordinator: nonceCoordinator) { [accountService, wallet] in
            await accountService.refreshReadOnlyToken(wallet: wallet, force: true)
        }
    }

    func openMarketContext(marketId: Int64, side: PerpsTradeSide) async -> PerpsOpenMarketContext? {
        guard let market = await marketProvider(marketId) else {
            Log.perps.w("openMarketContext market=\(marketId) metadata unavailable → load failed")
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
        await attempt("preview open") {
            guard let margin = PerpsMarketMath.optionalDouble(intent.marginUsd), margin > 0 else {
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
                marginUsd: margin
            )
        }
    }

    func prepareOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsPreparedTradingAction, PerpsTradingError> {
        await attempt("prepare open") {
            let planned = try await planOpen(intent)
            return PerpsPreparedTradingAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                intent: intent,
                review: planned.review
            )
        }
    }

    func submit(_ prepared: PerpsPreparedTradingAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        await submitAction(prepared, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planOpen(
                prepared.intent,
                session: session,
                operationId: prepared.operationId
            )
            return Submission(
                pending: pending(
                    prepared,
                    side: prepared.intent.side,
                    payload: .open(limitPrice: prepared.intent.limitPrice),
                    expectedBaseSize: planned.review.baseSize
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

    func submit(_ prepared: PerpsPreparedCloseAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        await submitAction(prepared, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planClose(
                marketId: prepared.marketId,
                context: self.marketContext(session: session, marketId: prepared.marketId),
                operationId: prepared.operationId
            )
            guard PerpsPlannerMapping.tradeSide(planned.side) == prepared.review.side else {
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
        await submitAction(prepared, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planSizeChange(
                prepared.intent,
                context: self.marketContext(session: session, marketId: prepared.intent.marketId),
                operationId: prepared.operationId,
                normalizedAutoClose: prepared.normalizedAutoClose
            )
            return Submission(
                pending: pending(
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

    func submit(_ prepared: PerpsPreparedMarginChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        await submitAction(prepared, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planMarginChange(
                prepared.intent,
                context: self.marketContext(session: session, marketId: prepared.intent.marketId),
                operationId: prepared.operationId
            )
            if prepared.intent.direction == .reduce, planned.isImmediateRisk {
                throw PerpsTradingError.immediateLiquidationRisk
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
        await submitAction(prepared, passcodeProvider: passcodeProvider) { session in
            let planned = try await self.planAutoCloseChange(
                prepared.intent,
                session: session,
                operationId: prepared.operationId
            )
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
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        await submitAction(prepared, passcodeProvider: passcodeProvider) { session in
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
               )
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
        await attempt("preview close") {
            try await planClose(marketId: intent.marketId, context: reviewContext(marketId: intent.marketId)).review
        }
    }

    func prepareClose(
        _ intent: PerpsCloseIntent
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError> {
        await attempt("prepare close") {
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
        await attempt("preview size change") {
            try await planSizeChange(intent, context: reviewContext(marketId: intent.marketId)).review
        }
    }

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError> {
        await attempt("prepare size change") {
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
        await attempt("preview margin change") {
            try await planMarginChange(intent, context: reviewContext(marketId: intent.marketId)).review
        }
    }

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError> {
        await attempt("prepare margin change") {
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
        await attempt("prepare auto-close change") {
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
        await attempt("prepare limit-order change") {
            if case let .modify(_, _, limitPrice) = intent, !(limitPrice.isFinite && limitPrice > 0) {
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

    /// One entry point for every operation: what to look at is in the payload, so
    /// no caller has to pick a method that matches the record it already holds.
    func reconcile(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        guard wallet.id == pending.walletId else { return .pending }
        switch pending.payload {
        case let .open(limitPrice):
            return await reconcileByState(pending, label: "open") { state in
                PerpsTkReconcile.open(
                    state: state,
                    isLimit: limitPrice != nil,
                    expectedBaseSize: pending.expectedBaseSize,
                    placementAccepted: pending.isOpenOrderAccepted
                )
            }
        case .close:
            return await reconcileByState(pending, label: "close") { state in
                PerpsTkReconcile.close(
                    state: state,
                    expectedBaseSize: pending.expectedBaseSize ?? pending.positionBaseSizeBefore
                )
            }
        case let .sizeChange(change, autoClose):
            let position = await reconcileSizeChange(pending, change: change, resolveOperation: true)
            guard let autoClose, position == .confirmed || position == .partiallyFilled else { return position }
            _ = await reconcileAutoClose(pending, change: autoClose)
            return position
        case let .marginChange(change):
            return await reconcileMargin(pending, change: change)
        case let .autoCloseChange(change):
            return await reconcileAutoClose(pending, change: change)
        case let .limitOrderChange(change):
            return await reconcileLimitOrder(pending, change: change)
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
            return PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: PerpsBackendMapping.ordersReadable(screen),
                matching: PerpsBackendMapping.matchingOrder(
                    screen.open_orders ?? [],
                    orderIndex: change.orderIndex
                ),
                placementAccepted: pending.hasOnlyAcceptedSignedSteps
            )
        }
    }

    func reconcileSizeChange(
        _ pending: PerpsPendingTradingAction,
        change: PerpsPendingSizeChange,
        resolveOperation: Bool
    ) async -> PerpsReconcileResult {
        guard pending.positionOrderRef != nil else {
            return await settle(pending, label: "sizeChange") {
                pending.hasOnlyAcceptedSignedSteps ? .notSubmitted : .pending
            }
        }
        return await settle(pending, label: "sizeChange", resolveOnConfirm: resolveOperation) {
            let state = try await loadPositionState(
                marketId: pending.marketId,
                clientOrderIndex: pending.positionOrderRef?.clientOrderIndex
            )
            let filled = state.orders.contains(where: PerpsBackendMapping.isFilled)
            if let canceled = state.orders.first(where: PerpsBackendMapping.isCanceled) {
                let filledBase = state.orders
                    .map { PerpsMarketMath.double($0.filled_base) }
                    .max() ?? 0
                return filled && filledBase > 0 ? .partiallyFilled : .failed(canceled.status)
            }
            let filledBase = state.orders
                .map { PerpsMarketMath.double($0.filled_base) }
                .max() ?? 0
            if let expected = change.expectedBaseDelta {
                let tolerance = max(0.000000001, abs(expected) * 1e-9)
                guard filledBase + tolerance >= expected else {
                    return filledBase > 0 ? .partiallyFilled : .pending
                }
                return .confirmed
            }
            guard filled else { return .pending }

            let positions = try await loadAccountSnapshot().positions
            guard let current = positions.first(where: { $0.marketId == pending.marketId }) else {
                return .confirmed
            }
            return PerpsChangeSettlement.sizeMoved(
                current: current.baseSize,
                before: change.baseSizeBefore,
                direction: change.direction,
                expectedDelta: change.expectedBaseDelta
            ) ? .confirmed : .pending
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
        await settle(pending, label: "autoClose") {
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
                },
                placementAccepted: pending.hasOnlyAcceptedSignedSteps
            )
        }
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
            guard let current = positions.first(where: { $0.marketId == pending.marketId }) else {
                return .failed("position_gone")
            }
            guard PerpsChangeSettlement.marginMoved(
                current: current.marginUsd,
                before: change.allocatedMarginBefore,
                amountUsd: change.amountUsd,
                direction: change.direction
            ) else {
                return pending.canStillLand(now: PerpsPlannerMapping.nowUnixMs())
                    ? .pending
                    : .failed("margin_unchanged")
            }
            return .confirmed
        }
    }

    func recoverInterruptedOperations() async {
        guard !Task.isCancelled else { return }
        do {
            try await recoverLocalPending(excluding: nil)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.perps.w("background operation recovery paused — \(mapped)")
        }
    }

    func renewExpiringAutoClose(marketIds: [Int64]) async {
        let now = Date()
        let due = !marketIds.isEmpty && autoCloseRenewalLock.withLock {
            if let checkedAt = autoCloseRenewalCheckedAt,
               now.timeIntervalSince(checkedAt) < Self.autoCloseRenewalCheckInterval
            {
                return false
            }
            autoCloseRenewalCheckedAt = now
            return true
        }
        guard due else { return }
        var completed = false
        defer {
            if !completed {
                autoCloseRenewalLock.withLock { autoCloseRenewalCheckedAt = nil }
            }
        }
        guard let session = try? await accountService.tradingSession(wallet: wallet) else { return }
        let deadline = PerpsPlannerMapping.nowUnixMs() / 1000 + Self.autoCloseRenewalLeadSeconds
        var everyMarketSettled = true
        for marketId in marketIds {
            guard !Task.isCancelled else { return }
            guard let context = try? await marketContext(session: session, marketId: marketId),
                  !(context.accountSnapshot.completeness is PerpsContextCompleteness.Incomplete)
            else {
                everyMarketSettled = false
                continue
            }
            let resting = intents.restingTriggerOrders(context)
            guard resting.contains(where: { $0.expiresAtSeconds > 0 && $0.expiresAtSeconds < deadline }) else { continue }
            guard let target = PerpsAutoClose(triggerOrders: resting),
                  case let .success(prepared) = await prepareAutoCloseChange(
                      PerpsAutoCloseChangeIntent(marketId: marketId, target: target, renewsExpiry: true)
                  )
            else {
                everyMarketSettled = false
                continue
            }
            let result = await submit(prepared, passcodeProvider: { nil })
            Log.perps.i("auto-close renewal market=\(marketId) result=\(result)")
            if case .failed = result { everyMarketSettled = false }
        }
        completed = everyMarketSettled && !Task.isCancelled
    }

    func marketsBlockedByPending() async -> Set<Int64> {
        let store = accountService.pendingJournal(wallet: wallet)
        guard let pendings = try? await store.allPending() else { return [] }
        let now = PerpsPlannerMapping.nowUnixMs()
        return Set(pendings.filter { $0.blocksPositionOrders(now: now) }.map(\.marketId))
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
        await attempt("margin change limits") {
            try PerpsPlannerMapping.marginChangeLimits(context: await reviewContext(marketId: marketId))
        }
    }
}

private extension PerpsTkTradingService {
    struct Submission {
        let pending: PerpsPendingTradingAction
        let execute: (_ execution: PerpsExecutionDelegate) async throws -> Void
    }

    struct PlannedOpen {
        let operationId: String
        let planned: PerpsPlannedTrade
        let review: PerpsOpenOrderReview
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
        304
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
        openInitialMarginBps: Int32? = nil
    ) async throws -> PerpsMarketContext {
        try await host.context(
            walletId: requireWalletId(),
            marketId: marketId,
            scope: await makeScope(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex),
            environment: environmentName,
            liveMark: await markPriceProvider(marketId),
            openInitialMarginBps: openInitialMarginBps
        )
    }

    /// The one place a thrown error becomes a domain failure, so every entry point
    /// that can throw reads as the work it does rather than as its error tail.
    func attempt<T>(_ operation: String, _ body: () async throws -> T) async -> Result<T, PerpsTradingError> {
        do {
            return try .success(await body())
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            switch mapped {
            case .activationCanceled, .nothingToChange:
                Log.perps.i("\(operation) stopped — \(mapped)")
            default:
                Log.perps.w("\(operation) failed — \(mapped)", error: error)
            }
            return .failure(mapped)
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
            liveMark: await markPriceProvider(marketId)
        )
    }

    func loadReviewer(
        marketId: Int64,
        intent: @escaping (PerpsMarketContext) throws -> PerpsTradeIntent
    ) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        await attempt("load reviewer") {
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

    func planOpen(_ intent: PerpsOpenMarketIntent) async throws -> PlannedOpen {
        try await planOpen(intent, session: requireSession())
    }

    func planOpen(
        _ intent: PerpsOpenMarketIntent,
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedOpen {
        guard let margin = PerpsMarketMath.optionalDouble(intent.marginUsd), margin > 0 else {
            throw PerpsTradingError.validation("amount is empty or invalid")
        }
        let context = try await marketContext(
            session: session,
            marketId: intent.marketId,
            openInitialMarginBps: PerpsPlannerMapping.initialMarginBps(leverage: intent.leverage)
        )
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
            review: PerpsPlannerMapping.openReview(review, symbol: symbol, marginUsd: margin)
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
            review: PerpsPlannerMapping.closeReview(review, symbol: symbol, leverage: leverage),
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
        let clientOrderIndices = try await intents.clientOrderIndices(for: context)
        let legs = try intents.autoCloseLegs(
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
            let delta = try PerpsScaled.parse(intent.marginDeltaUsd, decimals: scale.quoteDecimals, rounding: .down)
            guard delta < present.allocatedMarginQuote else {
                throw PerpsTradingError.validation("amount exceeds position margin")
            }
            let (product, overflow) = present.baseAmount.multipliedReportingOverflow(by: delta)
            guard !overflow else {
                throw PerpsTradingError.validation("position size is too large")
            }
            let baseStep = max(context.rules.baseStep, 1)
            let closeBase = product / present.allocatedMarginQuote / baseStep * baseStep
            guard closeBase > 0 else {
                throw PerpsTradingError.validation("amount is too small to reduce the position")
            }
            chainIntent = PerpsTradeIntent.Close(
                operationId: operationId,
                scope: context.scope,
                marketId: intent.marketId,
                positionId: present.positionId,
                side: present.side,
                positionBaseAmount: present.baseAmount,
                baseAmount: KotlinLong(value: closeBase),
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
                direction: .add,
                marginDeltaUsd: marginDelta,
                oldBase: present.baseAmount,
                oldEntry: present.entryPrice,
                oldNotionalUsd: oldNotionalUsd,
                liquidationBefore: present.liquidationPrice?.int64Value
            )
        } else if let close = planned.plan.review as? PerpetualReview.Close {
            review = PerpsPlannerMapping.closeSizeReview(
                close,
                symbol: symbol,
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
            : nil
        let order: PerpsLimitOrderSummary
        switch (resting, intent.kind, ordersReadable) {
        case let (.some(value), _, _):
            order = value
        case (.none, .cancel, false):
            throw PerpsTradingError.tradingUnavailable
        case (.none, .cancel, true):
            throw PerpsTradingError.nothingToChange
        case (.none, .modify, _):
            throw PerpsTradingError.stalePreparedTransaction
        }
        let context = try await marketContext(session: session, marketId: intent.marketId)
        let chainIntent: PerpsTradeIntent
        let normalizedPrice: Double?
        switch intent {
        case let .modify(_, _, limitPrice):
            let scaled = try PerpsScaled.scale(limitPrice, decimals: context.rules.scale.priceDecimals, rounding: .nearest)
            guard let resting = context.accountSnapshot.restingOrders.first(where: { $0.orderIndex == intent.orderIndex }) else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            let remaining = resting.remainingBaseAmount
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
            normalizedPrice = PerpsScaled.double(review.price, decimals: context.rules.scale.priceDecimals)
            guard let price = normalizedPrice,
                  !PerpsLimitOrderChangeSettlement.pricesMatch(price, order.limitPrice)
            else {
                throw PerpsTradingError.nothingToChange
            }
            return PlannedLimitChange(
                operationId: operationId,
                planned: planned,
                review: PerpsLimitOrderChangeReview(order: order, kind: .modify, limitPrice: normalizedPrice)
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
            review: PerpsLimitOrderChangeReview(order: order, kind: intent.kind, limitPrice: normalizedPrice)
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

    func submitAction(
        _ prepared: some PerpsPreparedAction,
        passcodeProvider: () async -> String?,
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult {
        let operationId = prepared.operationId
        let marketId = prepared.marketId
        guard wallet.id == prepared.walletId else {
            Log.perps.w("submit stale — wallet changed (market=\(marketId))")
            return .failed(.stalePreparedTransaction)
        }

        let session: PerpsAccountSession
        do {
            guard let resolved = try await accountService.tradingSession(wallet: wallet) else {
                return .failed(.activationRequired)
            }
            session = resolved
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.perps.w("submit session failed before signing \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }
        await accountService.ensurePlusTier(wallet: wallet, trigger: .trade)

        // A plan is validated against the read it was built from, so planning belongs in
        // the same lane as the signing it feeds: two operations that both plan before
        // either one sends would each build on the state before the other's orders.
        let scope = PerpsExecutionLock.Scope(
            environment: environmentName,
            accountIndex: session.accountIndex,
            apiKeyIndex: session.apiKeyIndex
        )
        do {
            return try await PerpsExecutionLock.shared.withScope(scope) {
                do {
                    // Only an unfinished operation that could still place an order on
                    // this market can interfere with this one. Anything else — another
                    // market, a margin move, a resting-order edit — is recovered in the
                    // same pass and holds nothing back here.
                    if try await recoverLocalPendingInLane(excluding: operationId).contains(marketId) {
                        Log.perps.w("unresolved pending blocks submit (market=\(marketId))")
                        return .failed(.operationInProgress)
                    }
                } catch {
                    let mapped = PerpsTradingErrorMapper.map(error)
                    Log.perps.w("pending recovery failed before submit \(mapped) (market=\(marketId))")
                    return .failed(mapped)
                }
                if let failure = await ensureIntegratorApproval(session: session, marketId: marketId, passcodeProvider: passcodeProvider) {
                    return .failed(failure)
                }
                if let result = await submitInLane(session: session, marketId: marketId, build: build) {
                    return result
                }
                // The approval this device recorded no longer holds on Lighter: it is signed
                // again and the operation repeated once.
                if let failure = await ensureIntegratorApproval(session: session, marketId: marketId, passcodeProvider: passcodeProvider) {
                    return .failed(failure)
                }
                return await submitInLane(session: session, marketId: marketId, build: build)
                    ?? .failed(.serverRejected("integrator not approved"))
            }
        } catch is CancellationError {
            return .failed(.operationInProgress)
        } catch {
            return .failed(PerpsTradingErrorMapper.map(error))
        }
    }

    private func ensureIntegratorApproval(
        session: PerpsAccountSession,
        marketId: Int64,
        passcodeProvider: () async -> String?
    ) async -> PerpsTradingError? {
        do {
            try await accountService.ensureIntegratorApproval(
                wallet: wallet,
                session: session,
                nonceCoordinator: nonceCoordinator,
                passcodeProvider: passcodeProvider
            )
            return nil
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.perps.w("integrator approval failed before submit \(mapped) (market=\(marketId))", error: error)
            return mapped
        }
    }

    /// Nil when an integrator refusal can be recovered by approving and rebuilding the operation.
    private func submitInLane(
        session: PerpsAccountSession,
        marketId: Int64,
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult? {
        let submission: Submission
        do {
            submission = try await build(session)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.perps.w("submit prepare failed before network submit \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        let store = accountService.pendingJournal(wallet: wallet)
        let pending: PerpsPendingTradingAction
        do {
            let result = try await store.savePendingIfAbsentWithStatus(submission.pending)
            guard result.inserted else {
                Log.perps.w("duplicate submit blocked operation=\(result.pending.operationId) market=\(marketId)")
                return .failed(.operationInProgress)
            }
            pending = result.pending
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.perps.w("pending journal failed before signing \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        Log.perps.i("submit start operation=\(pending.operationId) market=\(marketId) wallet=\(pending.walletId) side=\(pending.side) payload=\(pending.payload) expectedBase=\(pending.expectedBaseSize.map { "\($0)" } ?? "nil") baseBefore=\(pending.positionBaseSizeBefore.map { "\($0)" } ?? "nil")")
        var orderRefs = [PerpsPendingOrderRef]()
        var signedSteps = [PerpsPendingSignedStep]()
        func journaled() -> PerpsPendingTradingAction {
            var value = pending
            if !orderRefs.isEmpty { value.orderRefs = orderRefs }
            if !signedSteps.isEmpty { value.signedSteps = signedSteps }
            return value
        }
        let execution = PerpsExecutionRelay(
            api: perpsAPI,
            nonceCoordinator: nonceCoordinator,
            persistState: { signed, state in
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
                    Log.perps.i("step \(signed.stepId) signed operation=\(pending.operationId) attempt=\(signed.attemptId) nonce=\(signed.nonce) txType=\(signed.txType) hash=\(signed.txHash) orders=\(refs.map { "\($0.role):\($0.clientOrderIndex)" }) expiresAt=\(signed.transactionExpiryUnixMs)")
                } else if state == .unknown {
                    Log.perps.w("step \(signed.stepId) outcome unknown operation=\(pending.operationId) hash=\(signed.txHash)")
                }
                if let index = signedSteps.firstIndex(where: { $0.stepId == persisted.stepId }) {
                    signedSteps[index] = persisted
                } else {
                    signedSteps.append(persisted)
                }
                try await store.appendSignedStep(
                    operationId: pending.operationId,
                    step: persisted,
                    refs: refs
                )
            }
        )
        do {
            try await submission.execute(execution)
            Log.perps.i("submit accepted operation=\(pending.operationId) market=\(marketId)")
            return .submitted(journaled())
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            if execution.integratorNotApproved {
                accountService.forgetIntegratorApproval(wallet: wallet)
                // Leverage is an idempotent setting; accepted orders and margin moves must not be repeated.
                if signedSteps.allSatisfy({ $0.state != .accepted || $0.txType == LighterConstants.shared.TxTypeL2UpdateLeverage }),
                   (try? await store.removePending(operationId: pending.operationId)) != nil
                {
                    Log.perps.w("integrator not approved, operation dropped operation=\(pending.operationId) market=\(marketId)")
                    return nil
                }
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
            try? await store.removePending(operationId: pending.operationId)
            Log.perps.w("submit failed \(mapped) operation=\(pending.operationId) market=\(marketId)")
            return .failed(mapped)
        }
    }

    func reconcileByState(
        _ pending: PerpsPendingTradingAction,
        label: String,
        resolveOperation: Bool = true,
        decide: (Components.Schemas.PositionState) -> PerpsTkReconcile.Decision
    ) async -> PerpsReconcileResult {
        guard wallet.id == pending.walletId else { return .pending }
        return await settle(pending, label: label, resolveOnConfirm: resolveOperation) {
            // Without the exact client order key, a position snapshot cannot answer
            // this operation. Reading the unfiltered snapshot would accept a sibling
            // order from the same market as proof that this one filled.
            guard pending.positionOrderRef != nil else {
                if pending.hasOnlyAcceptedSignedSteps {
                    return .notSubmitted
                }
                if pending.canStillLand(now: PerpsPlannerMapping.nowUnixMs()) {
                    return .pending
                }
                Log.perps.w("reconcile(\(label)) has no order key market=\(pending.marketId)")
                return .notSubmitted
            }
            let state = try await loadPositionState(
                marketId: pending.marketId,
                clientOrderIndex: pending.positionOrderRef?.clientOrderIndex
            )
            let decision = decide(state)
            guard decision == .pending,
                  state.orders.isEmpty,
                  !pending.canStillLand(now: PerpsPlannerMapping.nowUnixMs())
            else {
                return decision
            }
            Log.perps.w("reconcile(\(label)) never reached the venue market=\(pending.marketId)")
            return .notSubmitted
        }
    }

    /// The one place a reconciliation decision turns into a result: a settled pending
    /// leaves the journal, a refusal is reported, and a read that failed is simply not
    /// an answer yet.
    func settle(
        _ pending: PerpsPendingTradingAction,
        label: String,
        resolveOnConfirm: Bool = true,
        decide: () async throws -> PerpsTkReconcile.Decision
    ) async -> PerpsReconcileResult {
        do {
            switch try await decide() {
            case .confirmed:
                if resolveOnConfirm {
                    await resolveSettled(pending, succeeded: true)
                }
                Log.perps.i("reconcile(\(label)) confirmed operation=\(pending.operationId) market=\(pending.marketId) side=\(pending.side)")
                return .confirmed
            case .partiallyFilled:
                if resolveOnConfirm {
                    await resolveSettled(pending, succeeded: true)
                }
                Log.perps.i("reconcile(\(label)) filled short of the reviewed size operation=\(pending.operationId) market=\(pending.marketId) side=\(pending.side)")
                return .partiallyFilled
            case let .failed(message):
                await resolveSettled(pending, succeeded: false)
                Log.perps.w("reconcile(\(label)) refused operation=\(pending.operationId) market=\(pending.marketId) — \(message)")
                return .failed(PerpsBackendMapping.isSlippageCancel(message) ? .slippageExceeded : .serverRejected(message))
            case .notSubmitted:
                await resolveSettled(pending, succeeded: false)
                Log.perps.w("reconcile(\(label)) not submitted, journal entry dropped operation=\(pending.operationId) market=\(pending.marketId)")
                return .failed(.stalePreparedTransaction)
            case .pending:
                Log.perps.i("reconcile(\(label)) still pending operation=\(pending.operationId) market=\(pending.marketId)")
                return .pending
            }
        } catch {
            Log.perps.w("reconcile(\(label)) read failed operation=\(pending.operationId) market=\(pending.marketId) — \(error)")
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
        return try await PerpsAPIError.reissuingReadOnlyToken({ await accountService.refreshReadOnlyToken(wallet: wallet, force: true) }) {
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
        let state = try await perpsAPI.positionState(
            walletId: requireWalletId(),
            id: PerpsPlannerMapping.tkPositionId(marketId: marketId),
            clientOrderIndex: clientOrderIndex
        )
        Log.perps.i("state market=\(marketId) coi=\(clientOrderIndex.map { "\($0)" } ?? "nil") open=\(state.open.map { "\($0.value1.side)@\($0.value1.opened_at)" } ?? "nil") lastClosed=\(state.last_closed.map { "\($0.value1.closed_at.map { "\($0)" } ?? "?")/\($0.value1.close_reason?.rawValue ?? "?")" } ?? "nil") orders=\(state.orders.map { "\($0.kind ?? "?"):\($0.status):\($0.filled_base ?? "-")" })")
        return state
    }

    /// Announced before the entry leaves the journal, so a reader that finds it gone
    /// already has the verdict the journal no longer keeps.
    func resolveSettled(_ pending: PerpsPendingTradingAction, succeeded: Bool) async {
        NotificationCenter.default.post(
            name: .perpsTradingOperationSettled,
            object: PerpsTradingSettlement(action: pending, succeeded: succeeded)
        )
        try? await accountService.pendingJournal(wallet: wallet)
            .removePending(operationId: pending.operationId)
    }

    func recoverLocalPending(excluding operationId: String?) async throws {
        guard let session = try await accountService.tradingSession(wallet: wallet) else {
            return
        }
        let scope = PerpsExecutionLock.Scope(
            environment: environmentName,
            accountIndex: session.accountIndex,
            apiKeyIndex: session.apiKeyIndex
        )
        _ = try await PerpsExecutionLock.shared.withScope(scope) {
            try await recoverLocalPendingInLane(excluding: operationId)
        }
    }

    /// Recovers every pending this wallet holds and answers with the markets whose
    /// own pending is still unresolved.
    private func recoverLocalPendingInLane(excluding operationId: String?) async throws -> Set<Int64> {
        try Task.checkCancellation()
        let store = accountService.pendingJournal(wallet: wallet)
        try await store.cleanupPending()
        let pendings = try await store.allPending()
        var unresolved = Set<Int64>()
        let now = PerpsPlannerMapping.nowUnixMs()
        for pending in pendings where pending.operationId != operationId {
            try Task.checkCancellation()
            Log.perps.i("recovery operation=\(pending.operationId) market=\(pending.marketId) payload=\(pending.payload) steps=\(pending.signedSteps?.map { "\($0.stepId):\($0.state)" } ?? []) orders=\(pending.orderRefs?.map { "\($0.role):\($0.clientOrderIndex)" } ?? []) blocks=\(pending.blocksPositionOrders(now: now))")
            if let sending = pending.signedSteps?.first(where: { $0.state == .sending }) {
                // SENDING is the crash window: the request may already have reached
                // the venue, so recovery must reconcile it, never send it again.
                try? await store.appendSignedStep(
                    operationId: pending.operationId,
                    step: sending.withState(.unknown),
                    refs: pending.orderRefs ?? []
                )
            }
            if let signed = pending.signedSteps?.first(where: { $0.state == .signed }) {
                do {
                    try Task.checkCancellation()
                    try await store.appendSignedStep(
                        operationId: pending.operationId,
                        step: signed.withState(.sending),
                        refs: pending.orderRefs ?? []
                    )
                    try Task.checkCancellation()
                    let relay = PerpsExecutionRelay(api: perpsAPI, nonceCoordinator: nonceCoordinator) { _ in }
                    try await relay.submitPersisted(
                        walletId: pending.walletId,
                        txType: signed.txType,
                        txInfo: signed.txInfo,
                        expectedTxHash: signed.txHash
                    )
                    try await store.appendSignedStep(
                        operationId: pending.operationId,
                        step: signed.withState(.accepted),
                        refs: pending.orderRefs ?? []
                    )
                } catch {
                    let mapped = PerpsTradingErrorMapper.map(error)
                    if !PerpsExecutionRelay.isAmbiguous(mapped),
                       (pending.orderRefs ?? []).isEmpty,
                       (pending.signedSteps ?? []).allSatisfy({ $0.state != .accepted })
                    {
                        Log.perps.w("recovery send refused \(mapped) operation=\(pending.operationId) market=\(pending.marketId)")
                        await resolveSettled(pending, succeeded: false)
                        continue
                    }
                    try? await store.appendSignedStep(
                        operationId: pending.operationId,
                        step: signed.withState(.unknown),
                        refs: pending.orderRefs ?? []
                    )
                    if pending.blocksPositionOrders(now: now) {
                        unresolved.insert(pending.marketId)
                    }
                    continue
                }
            }
            let current = (try? await store.pending(operationId: pending.operationId)) ?? pending
            if await reconcilePersisted(current) == false, current.blocksPositionOrders(now: now) {
                unresolved.insert(pending.marketId)
            }
        }
        return unresolved
    }

    func reconcilePersisted(_ pending: PerpsPendingTradingAction) async -> Bool {
        switch await reconcile(pending) {
        case .confirmed, .partiallyFilled, .failed: return true
        case .pending: return false
        }
    }
}
