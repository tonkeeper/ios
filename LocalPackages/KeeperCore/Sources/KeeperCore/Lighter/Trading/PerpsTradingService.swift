import ChainKit
import Foundation
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
        defaultLeverage: Double = 10,
        minLeverage: Double = 1,
        maxSlippage: Double = 0.01,
        closeMaxSlippage: Double = 0.02
    ) {
        self.defaultLeverage = defaultLeverage
        self.minLeverage = minLeverage
        self.maxSlippage = maxSlippage
        self.closeMaxSlippage = closeMaxSlippage
    }
}

public protocol PerpsTradingService: AnyObject {
    func openMarketContext(marketId: Int64, side: PerpsTradeSide) async -> PerpsOpenMarketContext?

    func previewOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsOpenOrderReview, PerpsTradingError>

    func prepareOpenMarket(
        _ intent: PerpsOpenMarketIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedTradingAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedTradingAction) async -> PerpsSubmitResult

    func reconcile(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult

    func prepareClose(
        _ intent: PerpsCloseIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedCloseAction) async -> PerpsSubmitResult

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedSizeChangeAction) async -> PerpsSubmitResult

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedMarginChangeAction) async -> PerpsSubmitResult

    func prepareAutoCloseChange(
        _ intent: PerpsAutoCloseChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedAutoCloseChangeAction) async -> PerpsSubmitResult

    func prepareLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction) async -> PerpsSubmitResult

    /// Reads the market once and hands back something that reviews trades over that
    /// read, synchronously. Submitting re-plans from a fresh read of its own, so a
    /// reviewer shows figures and never sends them.
    func loadReviewer(for intent: PerpsOpenMarketIntent) async -> Result<any PerpetualReviewer, PerpsTradingError>

    func loadReviewer(for intent: PerpsMarginChangeIntent) async -> Result<any PerpetualReviewer, PerpsTradingError>
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

    init(
        accountService: PerpsAccountService,
        wallet: Wallet,
        perpsAPI: PerpsAPI,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?,
        config: PerpsTradingConfig = PerpsTradingConfig()
    ) {
        self.accountService = accountService
        self.wallet = wallet
        self.perpsAPI = perpsAPI
        self.markPriceProvider = markPriceProvider
        self.marketProvider = marketProvider
        self.config = config
        intents = PerpsChainIntents(config: config)
        let nonceCoordinator = PerpsNonceCoordinator()
        self.nonceCoordinator = nonceCoordinator
        host = PerpsPlannerHost(api: perpsAPI, nonceCoordinator: nonceCoordinator)
    }

    func openMarketContext(marketId: Int64, side: PerpsTradeSide) async -> PerpsOpenMarketContext? {
        guard let market = await marketProvider(marketId) else {
            Log.w("🪵 Perps: openMarketContext market=\(marketId) metadata unavailable → load failed")
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
            minBaseSize: market.minBaseSize
        )
    }

    func previewOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsOpenOrderReview, PerpsTradingError> {
        await attempt {
            guard let margin = PerpsMarketMath.optionalDouble(intent.marginUsd), margin > 0 else {
                throw PerpsTradingError.validation("amount is empty or invalid")
            }
            let context = try await reviewContext(marketId: intent.marketId)
            let chainIntent = try intents.open(intent, context: context, operationId: UUID().uuidString)
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
        _ intent: PerpsOpenMarketIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedTradingAction, PerpsTradingError> {
        await attempt {
            let planned = try await planOpen(intent, passcodeProvider: passcodeProvider)
            return PerpsPreparedTradingAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                intent: intent,
                review: planned.review
            )
        }
    }

    func submit(_ prepared: PerpsPreparedTradingAction) async -> PerpsSubmitResult {
        await submitAction(prepared) { session in
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
                        signingKey: await self.signingKey(
                            accountIndex: session.accountIndex,
                            apiKeyIndex: session.apiKeyIndex
                        ),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedCloseAction) async -> PerpsSubmitResult {
        await submitAction(prepared) { session in
            let planned = try await self.planClose(marketId: prepared.marketId, session: session, operationId: prepared.operationId)
            guard PerpsPlannerMapping.tradeSide(planned.side) == prepared.review.side,
                  planned.baseAmount == prepared.positionBaseAmount
            else {
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
                        signingKey: await self.signingKey(
                            accountIndex: session.accountIndex,
                            apiKeyIndex: session.apiKeyIndex
                        ),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedSizeChangeAction) async -> PerpsSubmitResult {
        await submitAction(prepared) { session in
            let planned = try await self.planSizeChange(
                prepared.intent,
                session: session,
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
                        signingKey: await self.signingKey(
                            accountIndex: session.accountIndex,
                            apiKeyIndex: session.apiKeyIndex
                        ),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedMarginChangeAction) async -> PerpsSubmitResult {
        await submitAction(prepared) { session in
            let planned = try await self.planMarginChange(
                prepared.intent,
                session: session,
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
                        signingKey: await self.signingKey(
                            accountIndex: session.accountIndex,
                            apiKeyIndex: session.apiKeyIndex
                        ),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedAutoCloseChangeAction) async -> PerpsSubmitResult {
        await submitAction(prepared) { session in
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
                        signingKey: await self.signingKey(
                            accountIndex: session.accountIndex,
                            apiKeyIndex: session.apiKeyIndex
                        ),
                        execution: execution
                    )
                }
            )
        }
    }

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction) async -> PerpsSubmitResult {
        await submitAction(prepared) { session in
            let planned = try await self.planLimitOrderChange(
                prepared.intent,
                session: session,
                operationId: prepared.operationId
            )
            guard PerpsLimitOrderChangeSettlement.pricesMatch(
                planned.review.order.limitPrice,
                prepared.review.order.limitPrice
            ) else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            return Submission(
                pending: pending(prepared, side: planned.review.order.side, payload: .limitOrderChange(PerpsPendingLimitOrderChange(
                    orderIndex: planned.review.order.orderIndex,
                    kind: planned.review.kind,
                    limitPrice: planned.review.limitPrice
                ))),
                execute: { execution in
                    try await self.host.execute(
                        planned: planned.planned,
                        signingKey: await self.signingKey(
                            accountIndex: session.accountIndex,
                            apiKeyIndex: session.apiKeyIndex
                        ),
                        execution: execution
                    )
                }
            )
        }
    }

    func prepareClose(
        _ intent: PerpsCloseIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError> {
        await attempt {
            let session = try await requireSession(passcodeProvider: passcodeProvider)
            let planned = try await planClose(marketId: intent.marketId, session: session)
            return PerpsPreparedCloseAction(
                operationId: planned.operationId,
                walletId: wallet.id,
                marketId: intent.marketId,
                positionBaseAmount: planned.baseAmount,
                review: planned.review
            )
        }
    }

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError> {
        await attempt {
            let session = try await requireSession(passcodeProvider: passcodeProvider)
            let planned = try await planSizeChange(intent, session: session)
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

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError> {
        await attempt {
            let session = try await requireSession(passcodeProvider: passcodeProvider)
            let planned = try await planMarginChange(intent, session: session)
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
        _ intent: PerpsAutoCloseChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError> {
        await attempt {
            let session = try await requireSession(passcodeProvider: passcodeProvider)
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
        _ intent: PerpsLimitOrderChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError> {
        switch intent {
        case let .modify(_, _, limitPrice):
            guard limitPrice.isFinite, limitPrice > 0 else {
                return .failure(.validation("limit price is empty or invalid"))
            }
        case .cancel:
            break
        }
        return await attempt {
            let session = try await requireSession(passcodeProvider: passcodeProvider)
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
                    expectedBaseSize: pending.expectedBaseSize
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
            let position = await reconcileSizeChange(
                pending,
                change: change,
                resolveOperation: autoClose == nil
            )
            guard let autoClose, case .confirmed = position else { return position }
            return await reconcileAutoClose(pending, change: autoClose)
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
            let screen = try await loadTradingScreen(marketId: pending.marketId)
            return PerpsTkReconcile.limitChange(
                change: change,
                ordersVisible: PerpsBackendMapping.ordersVisible(screen.flags),
                matching: PerpsBackendMapping.matchingOrder(
                    screen.open_orders ?? [],
                    orderIndex: change.orderIndex
                )
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
                return .failed(filled && filledBase > 0 ? "partial_fill" : canceled.status)
            }
            let filledBase = state.orders
                .map { PerpsMarketMath.double($0.filled_base) }
                .max() ?? 0
            if let expected = change.expectedBaseDelta {
                let tolerance = max(0.000000001, abs(expected) * 1e-9)
                guard filledBase + tolerance >= expected else {
                    return filledBase > 0 ? .failed("partial_fill") : .pending
                }
            } else {
                guard filled else { return .pending }
            }

            let positions = try await loadAccountSnapshot().positions
            guard let current = positions.first(where: { $0.marketId == pending.marketId }) else {
                return .failed("position_gone")
            }
            if PerpsChangeSettlement.sizeMoved(
                current: current.baseSize,
                before: change.baseSizeBefore,
                direction: change.direction,
                expectedDelta: change.expectedBaseDelta
            ) {
                return .confirmed
            }
            return .pending
        }
    }

    /// Each leg is asked about by its own key, since the state endpoint answers
    /// for one order at a time. A cancel creates no order, so there the resting
    /// book is the only signal there is.
    func reconcileAutoClose(
        _ pending: PerpsPendingTradingAction,
        change: PerpsPendingAutoCloseChange
    ) async -> PerpsReconcileResult {
        await settle(pending, label: "autoClose") {
            let refs = pending.triggerOrderRefs
            for ref in refs {
                let state = try await loadPositionState(
                    marketId: pending.marketId,
                    clientOrderIndex: ref.clientOrderIndex
                )
                let leg = PerpsTkReconcile.autoCloseLeg(state: state)
                guard case .confirmed = leg else { return leg }
            }
            let screen = try await loadTradingScreen(marketId: pending.marketId)
            if PerpsBackendMapping.ordersVisible(screen.flags) {
                let orders = PerpsBackendMapping.triggerOrders(screen.open_orders)
                return PerpsAutoCloseChangePlanner.isConfirmed(pending: change, orders: orders) ? .confirmed : .pending
            }
            if !refs.isEmpty {
                return .confirmed
            }
            guard let detail = try await loadOpenPositionDetail(marketId: pending.marketId),
                  detail.auto_close_known == true
            else {
                return .pending
            }
            let orders = PerpsBackendMapping.triggerOrders(
                autoClose: detail.auto_close?.value1,
                side: pending.side
            )
            return PerpsAutoCloseChangePlanner.isConfirmed(pending: change, orders: orders) ? .confirmed : .pending
        }
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
                return .pending
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
            Log.w("🪵 Perps: background operation recovery paused — \(mapped)")
        }
    }

    func loadReviewer(
        for intent: PerpsOpenMarketIntent
    ) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        await loadReviewer(marketId: intent.marketId) { context in
            try self.intents.open(intent, context: context, operationId: UUID().uuidString)
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
        "mainnet"
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

    func requireSession(
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async throws -> PerpsAccountSession {
        switch await resolveSession(wallet: wallet, passcodeProvider: passcodeProvider) {
        case let .success(session): return session
        case let .failure(error): throw error
        }
    }

    func makeScope(accountIndex: Int64, apiKeyIndex: Int32) async throws -> PerpsScope {
        let key = try await signingKey(accountIndex: accountIndex, apiKeyIndex: apiKeyIndex)
        return try PerpsScope(
            walletId: requireWalletId(),
            venue: PerpsPlannerMapping.venue,
            chainId: chainId,
            environment: environmentName,
            accountIndex: accountIndex,
            apiKeyIndex: apiKeyIndex,
            keyBindingId: "\(accountIndex)/\(apiKeyIndex)",
            expectedPublicKey: key.publicKeyHex
        )
    }

    func signingKey(accountIndex: Int64, apiKeyIndex: Int32) async throws -> PerpsSigningKey {
        guard let hex = try await accountService.loadL2PrivateKeyHex(wallet: wallet), !hex.isEmpty else {
            throw PerpsTradingError.credentialsRevoked
        }
        return try host.signingKey(
            privateKeyHex: hex,
            accountIndex: accountIndex,
            apiKeyIndex: apiKeyIndex,
            chainId: chainId
        )
    }

    func resolvedSymbol(_ context: PerpsMarketContext, marketId: Int64) async -> String {
        if let symbol = context.symbol, !symbol.isEmpty {
            return symbol
        }
        return await marketProvider(marketId)?.symbol ?? ""
    }

    func marketContext(session: PerpsAccountSession, marketId: Int64) async throws -> PerpsMarketContext {
        try await host.context(
            walletId: requireWalletId(),
            marketId: marketId,
            scope: await makeScope(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex),
            environment: environmentName,
            liveMark: await markPriceProvider(marketId)
        )
    }

    /// The one place a thrown error becomes a domain failure, so every entry point
    /// that can throw reads as the work it does rather than as its error tail.
    func attempt<T>(_ body: () async throws -> T) async -> Result<T, PerpsTradingError> {
        do {
            return try .success(await body())
        } catch let error as PerpsTradingError {
            return .failure(error)
        } catch {
            Log.w("🪵 Perps: trading request failed", error: error)
            return .failure(PerpsTradingErrorMapper.map(error))
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
        await attempt {
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
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async throws -> PlannedOpen {
        try await planOpen(intent, session: requireSession(passcodeProvider: passcodeProvider))
    }

    func planOpen(
        _ intent: PerpsOpenMarketIntent,
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedOpen {
        guard let margin = PerpsMarketMath.optionalDouble(intent.marginUsd), margin > 0 else {
            throw PerpsTradingError.validation("amount is empty or invalid")
        }
        let context = try await marketContext(session: session, marketId: intent.marketId)
        let chainIntent = try intents.open(intent, context: context, operationId: operationId)
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
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedClose {
        let context = try await marketContext(session: session, marketId: marketId)
        let now = PerpsPlannerMapping.nowUnixMs()
        let present = try context.requirePosition()
        let chainIntent = try PerpsTradeIntent.Close(
            operationId: operationId,
            scope: context.scope,
            marketId: marketId,
            positionId: present.positionId,
            side: present.side,
            positionBaseAmount: present.baseAmount,
            baseAmount: nil,
            maxSlippagePpm: KotlinLong(value: PerpsPlannerMapping.slippagePpm(config.closeMaxSlippage)),
            clientOrderIndex: PerpsPlannerMapping.clientOrderIndex(nowUnixMs: now),
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
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString,
        normalizedAutoClose: PerpsAutoClose? = nil
    ) async throws -> PlannedSizeChange {
        guard let marginDelta = PerpsMarketMath.optionalDouble(intent.marginDeltaUsd), marginDelta > 0 else {
            throw PerpsTradingError.validation("amount is empty or invalid")
        }
        let context = try await marketContext(session: session, marketId: intent.marketId)
        let present = try context.requirePosition()
        let now = PerpsPlannerMapping.nowUnixMs()
        let scale = context.rules.scale
        let legs = try intents.autoCloseLegs(intent.autoCloseUpdate, context: context, now: now)
        let chainIntent: PerpsTradeIntent
        switch intent.direction {
        case .add:
            guard let known = context.accountSnapshot.marginSettings as? PerpsMarginSettings.Known else {
                throw PerpsTradingError.validation("position leverage unavailable")
            }
            let marginQuote = try PerpsScaled.parse(intent.marginDeltaUsd, decimals: scale.quoteDecimals)
            chainIntent = try PerpsTradeIntent.Add(
                operationId: operationId,
                scope: context.scope,
                marketId: intent.marketId,
                positionId: present.positionId,
                side: present.side,
                marginBudgetQuote: marginQuote,
                initialMarginBps: known.initialMarginBps,
                clientOrderIndex: PerpsPlannerMapping.clientOrderIndex(nowUnixMs: now),
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
            let delta = try PerpsScaled.parse(intent.marginDeltaUsd, decimals: scale.quoteDecimals)
            guard delta < present.allocatedMarginQuote else {
                throw PerpsTradingError.validation("amount exceeds position margin")
            }
            let (product, overflow) = present.baseAmount.multipliedReportingOverflow(by: delta)
            guard !overflow else {
                throw PerpsTradingError.validation("position size is too large")
            }
            let closeBase = product / present.allocatedMarginQuote
            guard closeBase > 0 else {
                throw PerpsTradingError.validation("amount is too small to reduce the position")
            }
            chainIntent = try PerpsTradeIntent.Close(
                operationId: operationId,
                scope: context.scope,
                marketId: intent.marketId,
                positionId: present.positionId,
                side: present.side,
                positionBaseAmount: present.baseAmount,
                baseAmount: KotlinLong(value: closeBase),
                maxSlippagePpm: KotlinLong(value: PerpsPlannerMapping.slippagePpm(config.closeMaxSlippage)),
                clientOrderIndex: PerpsPlannerMapping.clientOrderIndex(nowUnixMs: now),
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
                oldNotionalUsd: oldNotionalUsd
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
                oldNotionalUsd: oldNotionalUsd
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
        session: PerpsAccountSession,
        operationId: String = UUID().uuidString
    ) async throws -> PlannedMarginChange {
        guard let amount = PerpsMarketMath.optionalDouble(intent.amountUsd), amount > 0 else {
            throw PerpsTradingError.validation("amount is empty or invalid")
        }
        let context = try await marketContext(session: session, marketId: intent.marketId)
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
        let legs = try intents.autoCloseLegs(
            PerpsAutoCloseUpdate(
                desired: intent.target,
                resting: PerpsAutoClose(triggerOrders: intents.restingTriggerOrders(context))
            ),
            context: context,
            now: PerpsPlannerMapping.nowUnixMs()
        )
        guard let pending = legs.pending else {
            throw PerpsTradingError.nothingToChange
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
        guard let order = try await activeLimitOrder(
            marketId: intent.marketId,
            orderIndex: intent.orderIndex
        ) else {
            throw PerpsTradingError.stalePreparedTransaction
        }
        let context = try await marketContext(session: session, marketId: intent.marketId)
        let chainIntent: PerpsTradeIntent
        let normalizedPrice: Double?
        switch intent {
        case let .modify(_, _, limitPrice):
            let scaled = try PerpsScaled.scale(limitPrice, decimals: context.rules.scale.priceDecimals)
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

    func resolveSession(
        wallet: Wallet,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsAccountSession, PerpsTradingError> {
        do {
            if let session = try await accountService.tradingSession(wallet: wallet) {
                return .success(session)
            }
        } catch {
            return .failure(PerpsTradingErrorMapper.map(error))
        }

        guard let passcode = await passcodeProvider() else {
            return .failure(.activationCanceled)
        }
        let outcome = await accountService.activate(wallet: wallet, passcode: passcode)
        switch outcome {
        case .active:
            do {
                if let session = try await accountService.tradingSession(wallet: wallet) {
                    return .success(session)
                }
                return .failure(.activationRequired)
            } catch {
                return .failure(PerpsTradingErrorMapper.map(error))
            }
        case .noAccount:
            return .failure(.insufficientBalance)
        case .canceled:
            return .failure(.activationCanceled)
        case let .failed(error):
            return .failure(error)
        }
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
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult {
        let operationId = prepared.operationId
        let marketId = prepared.marketId
        guard wallet.id == prepared.walletId else {
            Log.w("🪵 Perps: submit stale — wallet changed (market=\(marketId))")
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
            Log.w("🪵 Perps: submit session failed before signing \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        // A plan is validated against the read it was built from, so planning belongs in
        // the same lane as the signing it feeds: two operations that both plan before
        // either one sends would each build on the state before the other's orders.
        let scope = PerpsExecutionLock.Scope(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex)
        do {
            return try await PerpsExecutionLock.shared.withScope(scope) {
                do {
                    if try await recoverLocalPendingInLane(excluding: operationId) {
                        Log.w("🪵 Perps: unresolved pending blocks submit (market=\(marketId))")
                        return .failed(.operationInProgress)
                    }
                } catch {
                    let mapped = PerpsTradingErrorMapper.map(error)
                    Log.w("🪵 Perps: pending recovery failed before submit \(mapped) (market=\(marketId))")
                    return .failed(mapped)
                }
                return await submitInLane(session: session, marketId: marketId, build: build)
            }
        } catch is CancellationError {
            return .failed(.operationInProgress)
        } catch {
            return .failed(PerpsTradingErrorMapper.map(error))
        }
    }

    private func submitInLane(
        session: PerpsAccountSession,
        marketId: Int64,
        build: (PerpsAccountSession) async throws -> Submission
    ) async -> PerpsSubmitResult {
        let submission: Submission
        do {
            submission = try await build(session)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: submit prepare failed before network submit \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        let store = accountService.pendingJournal(wallet: wallet)
        let pending: PerpsPendingTradingAction
        do {
            let result = try await store.savePendingIfAbsentWithStatus(submission.pending)
            guard result.inserted else {
                Log.w("🪵 Perps: duplicate submit blocked operation=\(result.pending.operationId) market=\(marketId)")
                return .failed(.operationInProgress)
            }
            pending = result.pending
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: pending journal failed before signing \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        Log.i("🪵 Perps: submit start operation=\(pending.operationId) market=\(marketId)")
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
            Log.i("🪵 Perps: submit accepted operation=\(pending.operationId) market=\(marketId)")
            return .submitted(journaled())
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
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
            Log.w("🪵 Perps: submit failed \(mapped) operation=\(pending.operationId) market=\(marketId)")
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
                if pending.signedSteps?.isEmpty == false {
                    return .pending
                }
                Log.w("🪵 Perps: reconcile(\(label)) has no order key market=\(pending.marketId)")
                return .notSubmitted
            }
            let state = try await loadPositionState(
                marketId: pending.marketId,
                clientOrderIndex: pending.positionOrderRef?.clientOrderIndex
            )
            return decide(state)
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
                    await resolveSettled(pending)
                }
                Log.i("🪵 Perps: reconcile(\(label)) confirmed market=\(pending.marketId) side=\(pending.side)")
                return .confirmed
            case let .failed(message):
                await resolveSettled(pending)
                Log.w("🪵 Perps: reconcile(\(label)) refused market=\(pending.marketId) — \(message)")
                return .failed(.serverRejected(message))
            case .notSubmitted:
                await resolveSettled(pending)
                return .failed(.stalePreparedTransaction)
            case .pending:
                Log.i("🪵 Perps: reconcile(\(label)) still pending market=\(pending.marketId)")
                return .pending
            }
        } catch {
            Log.w("🪵 Perps: reconcile(\(label)) read failed market=\(pending.marketId) — \(error)")
            return .pending
        }
    }

    func loadAccountSnapshot() async throws -> PerpsAccountSnapshot {
        let walletId = try requireWalletId()
        async let screen = perpsAPI.portfolioScreen(walletId: walletId)
        async let page = perpsAPI.listOpenPositions(walletId: walletId)
        return try await PerpsBackendMapping.snapshot(
            availableBalance: screen.balance?.available_balance ?? "0",
            positions: page.positions
        )
    }

    func loadTradingScreen(marketId: Int64) async throws -> Components.Schemas.TradingScreen {
        try await perpsAPI.tradingScreen(walletId: requireWalletId(), marketId: marketId)
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
        try await perpsAPI.positionState(
            walletId: requireWalletId(),
            id: PerpsPlannerMapping.tkPositionId(marketId: marketId),
            clientOrderIndex: clientOrderIndex
        )
    }

    func resolveSettled(_ pending: PerpsPendingTradingAction) async {
        try? await accountService.pendingJournal(wallet: wallet)
            .removePending(operationId: pending.operationId)
    }

    @discardableResult
    func recoverLocalPending(excluding operationId: String?) async throws -> Bool {
        guard let session = try await accountService.tradingSession(wallet: wallet) else {
            return false
        }
        let scope = PerpsExecutionLock.Scope(
            accountIndex: session.accountIndex,
            apiKeyIndex: session.apiKeyIndex
        )
        return try await PerpsExecutionLock.shared.withScope(scope) {
            try await recoverLocalPendingInLane(excluding: operationId)
        }
    }

    @discardableResult
    private func recoverLocalPendingInLane(excluding operationId: String?) async throws -> Bool {
        try Task.checkCancellation()
        let store = accountService.pendingJournal(wallet: wallet)
        try await store.cleanupPending()
        let pendings = try await store.allPending()
        var hasUnresolved = false
        for pending in pendings where pending.operationId != operationId {
            try Task.checkCancellation()
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
                    try? await store.appendSignedStep(
                        operationId: pending.operationId,
                        step: signed.withState(.unknown),
                        refs: pending.orderRefs ?? []
                    )
                    hasUnresolved = true
                    continue
                }
            }
            let current = (try? await store.pending(operationId: pending.operationId)) ?? pending
            if await reconcilePersisted(current) == false {
                hasUnresolved = true
            }
        }
        return hasUnresolved
    }

    func reconcilePersisted(_ pending: PerpsPendingTradingAction) async -> Bool {
        if case .confirmed = await reconcile(pending) { return true }
        return false
    }

    func activeLimitOrder(
        marketId: Int64,
        orderIndex: Int64
    ) async throws -> PerpsLimitOrderSummary? {
        let screen = try await loadTradingScreen(marketId: marketId)
        guard PerpsBackendMapping.ordersVisible(screen.flags) else { return nil }
        return PerpsBackendMapping.limitOrders(screen.open_orders)
            .first { $0.orderIndex == orderIndex }
    }
}
