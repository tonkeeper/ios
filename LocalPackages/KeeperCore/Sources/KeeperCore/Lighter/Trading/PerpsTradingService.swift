import ChainKit
import Foundation
import TKLogging

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

    func reconcileOpenMarket(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult

    func prepareClose(
        _ intent: PerpsCloseIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedCloseAction) async -> PerpsSubmitResult

    func reconcileClose(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedSizeChangeAction) async -> PerpsSubmitResult

    func reconcileSizeChange(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedMarginChangeAction) async -> PerpsSubmitResult

    func reconcileMarginChange(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult

    func prepareAutoCloseChange(
        _ intent: PerpsAutoCloseChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedAutoCloseChangeAction) async -> PerpsSubmitResult

    func reconcileAutoCloseChange(_ pending: PerpsPendingTradingAction) async -> PerpsAutoCloseReconcileResult

    func prepareLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction) async -> PerpsSubmitResult

    func reconcileLimitOrderChange(_ pending: PerpsPendingTradingAction) async -> PerpsLimitOrderChangeReconcileResult

    func previewLiquidation(
        side: PerpsTradeSide,
        marginUsd: Double,
        leverage: Double,
        openingFeeRate: Double,
        entryPrice: Double,
        markPrice: Double,
        maintenanceFraction: Double
    ) -> PerpsLiquidationPreview

    func previewPositionLiquidation(
        side: PerpsTradeSide,
        baseSize: Double,
        entryPrice: Double,
        markPrice: Double,
        maintenanceFraction: Double,
        collateralUsd: Double
    ) -> PerpsLiquidationPreview
}

final class LighterPerpsTradingService: PerpsTradingService, @unchecked Sendable {
    private let activationService: LighterActivationService
    private let wallet: Wallet
    private let markPriceProvider: @Sendable (Int64) async -> Double?
    private let marketProvider: @Sendable (Int64) async -> PerpsMarketMetadata?
    private let config: PerpsTradingConfig

    init(
        activationService: LighterActivationService,
        wallet: Wallet,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?,
        config: PerpsTradingConfig = PerpsTradingConfig()
    ) {
        self.activationService = activationService
        self.wallet = wallet
        self.markPriceProvider = markPriceProvider
        self.marketProvider = marketProvider
        self.config = config
    }

    func openMarketContext(marketId: Int64, side: PerpsTradeSide) async -> PerpsOpenMarketContext? {
        guard let market = await marketProvider(marketId) else {
            Log.w("🪵 Perps: openMarketContext market=\(marketId) metadata unavailable → load failed")
            return nil
        }
        let maxLeverage = max(config.minLeverage, market.maxLeverage)
        var maintenanceFraction: Double?
        if let meta = try? await marketMeta(wallet: wallet, marketId: marketId) {
            maintenanceFraction = meta.maintenanceFraction
        }

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
            maintenanceFraction: maintenanceFraction,
            minBaseSize: market.minBaseSize,
            takerFee: market.takerFee
        )
    }

    func previewOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsOpenOrderReview, PerpsTradingError> {
        let session: LighterSession
        do {
            guard let value = try await activationService.tradingSession(wallet: wallet) else {
                return .failure(.activationRequired)
            }
            session = value
        } catch {
            return .failure(PerpsTradingErrorMapper.map(error))
        }
        guard let request = await makeOpenOrderRequest(intent: intent) else {
            Log.w("🪵 Perps: preview rejected — empty/invalid amount (market=\(intent.marketId))")
            return .failure(.validation("amount is empty or invalid"))
        }

        do {
            let review: LighterOrderReview
            switch request.chainKitIntent {
            case let .limit(limitIntent):
                review = try await bridgeKotlin { completion in
                    session.trading.previewOpenLimit(intent: limitIntent, completionHandler: completion)
                }
            case let .market(openIntent):
                review = try await bridgeKotlin { completion in
                    session.trading.previewOpenMarket(intent: openIntent, completionHandler: completion)
                }
            }
            return .success(PerpsOpenOrderReviewMapper.map(review: review, marginUsd: request.marginUsd))
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: preview failed market=\(intent.marketId) — \(mapped)")
            return .failure(mapped)
        }
    }

    func prepareOpenMarket(
        _ intent: PerpsOpenMarketIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedTradingAction, PerpsTradingError> {
        guard let request = await makeOpenOrderRequest(intent: intent) else {
            Log.w("🪵 Perps: prepare rejected — empty/invalid amount (market=\(intent.marketId))")
            return .failure(.validation("amount is empty or invalid"))
        }
        Log.i("🪵 Perps: prepare start market=\(intent.marketId) side=\(intent.side) lev=\(intent.leverage)x notional=\(request.notionalUsd)")

        let session: LighterSession
        switch await resolveSession(wallet: wallet, passcodeProvider: passcodeProvider) {
        case let .success(value): session = value
        case let .failure(error): return .failure(error)
        }
        let trading = session.trading

        do {
            let review: LighterOrderReview
            switch request.chainKitIntent {
            case let .limit(limitIntent):
                review = try await bridgeKotlin { completion in
                    trading.previewOpenLimit(intent: limitIntent, completionHandler: completion)
                }
            case let .market(openIntent):
                review = try await bridgeKotlin { completion in
                    trading.previewOpenMarket(intent: openIntent, completionHandler: completion)
                }
            }

            let prepared = PerpsPreparedTradingAction(
                operationId: UUID().uuidString,
                walletId: wallet.id,
                isTestnet: activationService.isTestnet,
                marketId: intent.marketId,
                intent: intent,
                review: PerpsOpenOrderReviewMapper.map(
                    review: review,
                    marginUsd: request.marginUsd
                )
            )
            Log.i("🪵 Perps: prepare preview ok market=\(intent.marketId)")
            return .success(prepared)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: prepare failed market=\(intent.marketId) — \(mapped)")
            return .failure(mapped)
        }
    }

    func submit(_ prepared: PerpsPreparedTradingAction) async -> PerpsSubmitResult {
        await submitOpenMarket(prepared)
    }

    func submit(_ prepared: PerpsPreparedCloseAction) async -> PerpsSubmitResult {
        await submitClose(prepared)
    }

    func submit(_ prepared: PerpsPreparedSizeChangeAction) async -> PerpsSubmitResult {
        await submitSizeChange(prepared)
    }

    func submit(_ prepared: PerpsPreparedMarginChangeAction) async -> PerpsSubmitResult {
        await submitMarginChange(prepared)
    }

    func submit(_ prepared: PerpsPreparedAutoCloseChangeAction) async -> PerpsSubmitResult {
        await submitAutoCloseChange(prepared)
    }

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction) async -> PerpsSubmitResult {
        await submitLimitOrderChange(prepared)
    }

    func prepareClose(
        _ intent: PerpsCloseIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError> {
        Log.i("🪵 Perps: prepareClose start market=\(intent.marketId)")

        let session: LighterSession
        switch await resolveSession(wallet: wallet, passcodeProvider: passcodeProvider) {
        case let .success(value): session = value
        case let .failure(error): return .failure(error)
        }
        let trading = session.trading

        do {
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                trading.currentPosition(marketId: intent.marketId, completionHandler: $0)
            }
            guard let position, abs(position.size) > 0 else {
                Log.w("🪵 Perps: prepareClose rejected — no open position (market=\(intent.marketId))")
                return .failure(.positionNotFound)
            }

            let closeIntent = CloseIntent(
                marketId: intent.marketId,
                portion: 1.0,
                maxSlippage: config.closeMaxSlippage,
                clientOrderIndex: 0,
                markPrice: await markPriceProvider(intent.marketId).map { KotlinDouble(value: $0) }
            )
            let review: LighterOrderReview = try await bridgeKotlin { completion in
                trading.previewClose(intent: closeIntent, completionHandler: completion)
            }

            let prepared = PerpsPreparedCloseAction(
                operationId: UUID().uuidString,
                walletId: wallet.id,
                isTestnet: activationService.isTestnet,
                marketId: intent.marketId,
                review: PerpsCloseReviewMapper.map(review: review, position: position)
            )
            Log.i("🪵 Perps: prepareClose ok market=\(intent.marketId)")
            return .success(prepared)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: prepareClose failed market=\(intent.marketId) — \(mapped)")
            return .failure(mapped)
        }
    }

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError> {
        guard let marginDelta = decimalDouble(intent.marginDeltaUsd), marginDelta > 0 else {
            Log.w("🪵 Perps: prepareSizeChange rejected — empty/invalid amount (market=\(intent.marketId))")
            return .failure(.validation("amount is empty or invalid"))
        }
        Log.i("🪵 Perps: prepareSizeChange start market=\(intent.marketId) direction=\(intent.direction.rawValue)")

        let session: LighterSession
        switch await resolveSession(wallet: wallet, passcodeProvider: passcodeProvider) {
        case let .success(value): session = value
        case let .failure(error): return .failure(error)
        }
        let trading = session.trading

        do {
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                trading.currentPosition(marketId: intent.marketId, completionHandler: $0)
            }
            guard let position, abs(position.size) > 0 else {
                Log.w("🪵 Perps: prepareSizeChange rejected — no open position (market=\(intent.marketId))")
                return .failure(.positionNotFound)
            }
            let markPrice = await markPriceProvider(intent.marketId).map { KotlinDouble(value: $0) }

            let review: LighterOrderReview
            switch intent.direction {
            case .add:
                guard let leverage = positionLeverage(position), leverage > 0 else {
                    Log.w("🪵 Perps: prepareSizeChange rejected — leverage unavailable (market=\(intent.marketId))")
                    return .failure(.validation("position leverage unavailable"))
                }
                review = try await bridgeKotlin { completion in
                    trading.previewAddToPosition(
                        marketId: intent.marketId,
                        amount: LighterAmountQuote(usd: marginDelta * leverage),
                        maxSlippage: config.maxSlippage,
                        markPrice: markPrice,
                        marginUsd: KotlinDouble(value: marginDelta),
                        completionHandler: completion
                    )
                }
            case .reduce:
                let margin = position.allocatedMargin
                guard margin > 0, marginDelta < margin else {
                    Log.w("🪵 Perps: prepareSizeChange rejected — reduce ≥ position margin (market=\(intent.marketId))")
                    return .failure(.validation("amount exceeds position margin"))
                }
                review = try await bridgeKotlin { completion in
                    trading.previewClose(
                        intent: CloseIntent(
                            marketId: intent.marketId,
                            portion: marginDelta / margin,
                            maxSlippage: config.closeMaxSlippage,
                            clientOrderIndex: 0,
                            markPrice: markPrice
                        ),
                        completionHandler: completion
                    )
                }
            }

            var normalizedAutoClose: PerpsAutoClose?
            if case let .replace(autoClose) = intent.autoCloseUpdate,
               let tpSl = tpSl(from: autoClose)
            {
                guard let projectedPosition = review.positionAfter else {
                    return .failure(.validation("position change does not leave a position for auto-close"))
                }
                let tpSlReview: LighterTpSlReview = try await bridgeKotlin { completion in
                    trading.previewTpSl(tpSl: tpSl, position: projectedPosition, completionHandler: completion)
                }
                normalizedAutoClose = PerpsAutoCloseChangeReviewMapper.map(
                    review: tpSlReview,
                    position: position
                ).new
            }

            let prepared = PerpsPreparedSizeChangeAction(
                operationId: UUID().uuidString,
                walletId: wallet.id,
                isTestnet: activationService.isTestnet,
                marketId: intent.marketId,
                intent: intent,
                review: PerpsSizeChangeReviewMapper.map(
                    direction: intent.direction,
                    review: review,
                    position: position,
                    marginDeltaUsd: marginDelta
                ),
                normalizedAutoClose: normalizedAutoClose
            )
            Log.i("🪵 Perps: prepareSizeChange preview ok market=\(intent.marketId)")
            return .success(prepared)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: prepareSizeChange failed market=\(intent.marketId) — \(mapped)")
            return .failure(mapped)
        }
    }

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError> {
        guard let amount = decimalDouble(intent.amountUsd), amount > 0 else {
            Log.w("🪵 Perps: prepareMarginChange rejected — empty/invalid amount (market=\(intent.marketId))")
            return .failure(.validation("amount is empty or invalid"))
        }
        Log.i("🪵 Perps: prepareMarginChange start market=\(intent.marketId) direction=\(intent.direction.rawValue)")

        let session: LighterSession
        switch await resolveSession(wallet: wallet, passcodeProvider: passcodeProvider) {
        case let .success(value): session = value
        case let .failure(error): return .failure(error)
        }
        let trading = session.trading

        do {
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                trading.currentPosition(marketId: intent.marketId, completionHandler: $0)
            }
            guard let position, abs(position.size) > 0 else {
                Log.w("🪵 Perps: prepareMarginChange rejected — no open position (market=\(intent.marketId))")
                return .failure(.positionNotFound)
            }
            if intent.direction == .reduce {
                guard amount < position.allocatedMargin else {
                    Log.w("🪵 Perps: prepareMarginChange rejected — reduce ≥ allocated margin (market=\(intent.marketId))")
                    return .failure(.validation("amount exceeds position margin"))
                }
            }

            let markPrice = await markPriceProvider(intent.marketId).map { KotlinDouble(value: $0) }
            let review: LighterMarginReview
            switch intent.direction {
            case .add:
                review = try await bridgeKotlin { completion in
                    trading.previewAddMargin(marketId: intent.marketId, usdc: amount, markPrice: markPrice, completionHandler: completion)
                }
            case .reduce:
                review = try await bridgeKotlin { completion in
                    trading.previewReduceMargin(marketId: intent.marketId, usdc: amount, markPrice: markPrice, completionHandler: completion)
                }
            }
            let mapped = PerpsMarginChangeReviewMapper.map(
                direction: intent.direction,
                review: review,
                position: position
            )
            // Withdrawing collateral into immediate risk is never right; adding
            // margin is allowed even when the flag stays set — it only helps.
            if intent.direction == .reduce, mapped.isImmediateRisk {
                Log.w("🪵 Perps: prepareMarginChange rejected — immediate risk after reduce (market=\(intent.marketId))")
                return .failure(.immediateLiquidationRisk)
            }

            let prepared = PerpsPreparedMarginChangeAction(
                operationId: UUID().uuidString,
                walletId: wallet.id,
                isTestnet: activationService.isTestnet,
                marketId: intent.marketId,
                intent: intent,
                review: mapped
            )
            Log.i("🪵 Perps: prepareMarginChange ok market=\(intent.marketId)")
            return .success(prepared)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: prepareMarginChange failed market=\(intent.marketId) — \(mapped)")
            return .failure(mapped)
        }
    }

    func prepareAutoCloseChange(
        _ intent: PerpsAutoCloseChangeIntent,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError> {
        Log.i("🪵 Perps: prepareAutoCloseChange start market=\(intent.marketId)")

        let session: LighterSession
        switch await resolveSession(wallet: wallet, passcodeProvider: passcodeProvider) {
        case let .success(value): session = value
        case let .failure(error): return .failure(error)
        }
        let trading = session.trading

        do {
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                trading.currentPosition(marketId: intent.marketId, completionHandler: $0)
            }
            guard let position, abs(position.size) > 0 else {
                Log.w("🪵 Perps: prepareAutoCloseChange rejected — no open position (market=\(intent.marketId))")
                return .failure(.positionNotFound)
            }
            let resting = try await activationService.activeTriggerOrders(
                wallet: wallet,
                accountIndex: session.accountIndex,
                marketId: intent.marketId
            )

            let review: PerpsAutoCloseChangeReview
            switch PerpsAutoCloseChangePlanner.plan(target: intent.target, resting: resting) {
            case .noChange:
                Log.w("🪵 Perps: prepareAutoCloseChange rejected — nothing to change (market=\(intent.marketId))")
                return .failure(.nothingToChange)
            case let .replace(target, _):
                guard let tpSl = tpSl(from: target) else {
                    return .failure(.validation("no auto-close change to submit"))
                }
                let tpSlReview: LighterTpSlReview = try await bridgeKotlin { completion in
                    trading.previewTpSl(marketId: intent.marketId, tpSl: tpSl, completionHandler: completion)
                }
                review = PerpsAutoCloseChangeReviewMapper.map(review: tpSlReview, position: position)
            case .clear:
                review = PerpsAutoCloseChangeReviewMapper.mapCancel(position: position)
            }

            let prepared = PerpsPreparedAutoCloseChangeAction(
                operationId: UUID().uuidString,
                walletId: wallet.id,
                isTestnet: activationService.isTestnet,
                marketId: intent.marketId,
                intent: intent,
                review: review
            )
            Log.i("🪵 Perps: prepareAutoCloseChange ok market=\(intent.marketId)")
            return .success(prepared)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: prepareAutoCloseChange failed market=\(intent.marketId) — \(mapped)")
            return .failure(mapped)
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

        let session: LighterSession
        switch await resolveSession(wallet: wallet, passcodeProvider: passcodeProvider) {
        case let .success(value): session = value
        case let .failure(error): return .failure(error)
        }

        do {
            guard let order = try await activeLimitOrder(
                wallet: wallet,
                accountIndex: session.accountIndex,
                marketId: intent.marketId,
                orderIndex: intent.orderIndex
            ) else {
                return .failure(.stalePreparedTransaction)
            }

            let normalizedPrice: Double?
            switch intent.kind {
            case .modify:
                let review: LighterModifyOrderReview = try await bridgeKotlin { completion in
                    session.trading.previewModifyLimitOrder(
                        intent: ModifyLimitOrderIntent(
                            marketId: intent.marketId,
                            orderIndex: intent.orderIndex,
                            limitPrice: intent.limitPrice ?? 0,
                            size: nil
                        ),
                        completionHandler: completion
                    )
                }
                guard !PerpsLimitOrderChangeSettlement.pricesMatch(review.priceHuman, order.limitPrice) else {
                    return .failure(.nothingToChange)
                }
                normalizedPrice = review.priceHuman
            case .cancel:
                normalizedPrice = nil
            }

            return .success(PerpsPreparedLimitOrderChangeAction(
                operationId: UUID().uuidString,
                walletId: wallet.id,
                isTestnet: activationService.isTestnet,
                marketId: intent.marketId,
                intent: intent,
                review: PerpsLimitOrderChangeReview(
                    order: order,
                    kind: intent.kind,
                    limitPrice: normalizedPrice
                )
            ))
        } catch {
            return .failure(PerpsTradingErrorMapper.map(error))
        }
    }

    func reconcileLimitOrderChange(
        _ pending: PerpsPendingTradingAction
    ) async -> PerpsLimitOrderChangeReconcileResult {
        guard let change = pending.limitOrderChange,
              wallet.id == pending.walletId
        else {
            return .pending
        }
        let accountIndex: Int64
        switch await activationService.status(wallet: wallet) {
        case let .active(index, _), let .accountExists(index): accountIndex = index
        default: return .pending
        }

        do {
            let active = try await activationService.activeOrders(
                wallet: wallet,
                accountIndex: accountIndex,
                marketId: pending.marketId
            )
            if let order = active.first(where: { $0.orderIndex == change.orderIndex }) {
                if PerpsLimitOrderChangeSettlement.activeOrderConfirms(
                    change: change,
                    price: PerpsMarketMath.double(order.price)
                ) {
                    guard await resolveSucceeded(pending, wallet: wallet) else { return .pending }
                    return .confirmed
                }
                return .pending
            }

            let inactive = try await activationService.inactiveOrders(
                wallet: wallet,
                accountIndex: accountIndex,
                marketId: pending.marketId
            )
            guard let order = inactive.first(where: { $0.orderIndex == change.orderIndex }) else {
                return .pending
            }

            let succeeded = PerpsLimitOrderChangeSettlement.inactiveOrderConfirms(
                change: change,
                price: PerpsMarketMath.double(order.price),
                isCanceled: order.isCanceled
            )
            if succeeded {
                guard await resolveSucceeded(pending, wallet: wallet) else { return .pending }
                return .confirmed
            }

            guard await resolveFailed(pending, wallet: wallet, message: order.status) else {
                return .pending
            }
            return .failed(.serverRejected(order.status))
        } catch {
            Log.w("🪵 Perps: reconcile(limitOrderChange) read failed market=\(pending.marketId) — \(error)")
            return .pending
        }
    }

    /// Confirms by the trigger-order delta, not the position: the reloaded
    /// active orders are compared against the pending target (or the cleared
    /// indexes) via `PerpsAutoCloseChangePlanner.isConfirmed`.
    func reconcileAutoCloseChange(_ pending: PerpsPendingTradingAction) async -> PerpsAutoCloseReconcileResult {
        guard let change = pending.autoCloseChange else { return .pending }
        guard wallet.id == pending.walletId else { return .pending }
        let accountIndex: Int64
        switch await activationService.status(wallet: wallet) {
        case let .active(index, _), let .accountExists(index): accountIndex = index
        default: return .pending
        }
        do {
            let orders = try await activationService.activeTriggerOrders(
                wallet: wallet,
                accountIndex: accountIndex,
                marketId: pending.marketId
            )
            if PerpsAutoCloseChangePlanner.isConfirmed(pending: change, orders: orders) {
                guard await resolveSucceeded(pending, wallet: wallet) else { return .pending }
                Log.i("🪵 Perps: reconcile(autoClose) confirmed market=\(pending.marketId)")
                return .confirmed(orders)
            }
            if let portfolio = try await activationService.portfolio(wallet: wallet, accountIndex: accountIndex),
               !portfolio.positions.contains(where: { $0.marketId == pending.marketId })
            {
                // Once the protected position is gone, no resting TP/SL target is
                // applicable. This also covers a trigger firing during reconciliation.
                guard await resolveSucceeded(pending, wallet: wallet) else { return .pending }
                return .confirmed(orders)
            }
            let clientOrderIndexes = try await operationOrderIndexes(pending, wallet: wallet)
            if !clientOrderIndexes.isEmpty {
                let inactive = try await activationService.inactiveOrders(
                    wallet: wallet,
                    accountIndex: accountIndex,
                    marketId: pending.marketId
                )
                if let rejected = inactive.first(where: {
                    clientOrderIndexes.contains($0.clientOrderIndex) && $0.isExecutionRejected
                }) {
                    guard await resolveFailed(pending, wallet: wallet, message: rejected.status) else {
                        return .pending
                    }
                    return .failed(.serverRejected(rejected.status))
                }
            }
            Log.i("🪵 Perps: reconcile(autoClose) still pending market=\(pending.marketId)")
            return .pending
        } catch {
            Log.w("🪵 Perps: reconcile(autoClose) read failed market=\(pending.marketId) — \(error)")
            return .pending
        }
    }

    func reconcileOpenMarket(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        guard wallet.id == pending.walletId else { return .pending }
        let accountIndex: Int64
        switch await activationService.status(wallet: wallet) {
        case let .active(index, _), let .accountExists(index): accountIndex = index
        default: return .pending
        }

        do {
            guard let portfolio = try await activationService.portfolio(wallet: wallet, accountIndex: accountIndex) else {
                return .pending
            }
            let positions = portfolio.positions.compactMap(PerpsPositionSummary.init(position:))
            if let position = positions.first(where: {
                $0.marketId == pending.marketId && $0.side == pending.side
            }) {
                let moved = pending.positionBaseSizeBefore.map { position.baseSize > $0 } ?? true
                if moved {
                    guard await resolveSucceeded(pending, wallet: wallet) else { return .pending }
                    return .confirmed(positions: positions, availableBalance: portfolio.availableBalance)
                }
            }

            guard let clientOrderIndex = try await operationOrderIndexes(pending, wallet: wallet).first else {
                return .pending
            }

            let active = try await activationService.activeOrders(
                wallet: wallet,
                accountIndex: accountIndex,
                marketId: pending.marketId
            )
            if pending.limitPrice != nil,
               active.contains(where: { $0.clientOrderIndex == clientOrderIndex })
            {
                guard await resolveSucceeded(pending, wallet: wallet) else { return .pending }
                return .confirmed(positions: positions, availableBalance: portfolio.availableBalance)
            }

            let inactive = try await activationService.inactiveOrders(
                wallet: wallet,
                accountIndex: accountIndex,
                marketId: pending.marketId
            )
            if let order = inactive.first(where: { $0.clientOrderIndex == clientOrderIndex }) {
                if order.isFilled {
                    guard await resolveSucceeded(pending, wallet: wallet) else { return .pending }
                    return .confirmed(positions: positions, availableBalance: portfolio.availableBalance)
                }
                if order.isExecutionRejected {
                    guard await resolveFailed(pending, wallet: wallet, message: order.status) else { return .pending }
                    return .failed(.serverRejected(order.status))
                }
            }
            return .pending
        } catch {
            Log.w("🪵 Perps: reconcile(open) read failed market=\(pending.marketId) — \(error)")
            return .pending
        }
    }

    /// A reduce-only IOC close is confirmed when the original-side position is
    /// absent or smaller than its durable pre-submit baseline. This resolves both
    /// complete and legitimate partial fills without letting an unchanged canceled
    /// order unblock the nonce lane.
    func reconcileClose(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        await reconcile(pending, label: "close") { positions in
            guard let position = positions.first(where: { $0.marketId == pending.marketId }) else {
                return true
            }
            guard position.side == pending.side else { return true }
            guard let before = pending.positionBaseSizeBefore else { return false }
            return PerpsChangeSettlement.closeMoved(current: position.baseSize, before: before)
        }
    }

    /// A vanished position still confirms a reduce — a liquidation or full fill that
    /// raced the order leaves the size lower either way; an add with no position
    /// stays pending until the authoritative snapshot explains it.
    func reconcileSizeChange(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        let positionResult = await reconcile(
            pending,
            label: "sizeChange",
            resolveOperation: pending.autoCloseChange == nil
        ) { positions in
            guard let sizeChange = pending.sizeChange else { return false }
            guard let current = positions.first(where: { $0.marketId == pending.marketId }) else {
                return sizeChange.direction == .reduce
            }
            return PerpsChangeSettlement.sizeMoved(
                current: current.baseSize,
                before: sizeChange.baseSizeBefore,
                direction: sizeChange.direction
            )
        }
        guard pending.autoCloseChange != nil else { return positionResult }
        guard case .confirmed = positionResult else { return positionResult }
        switch await reconcileAutoCloseChange(pending) {
        case .confirmed: return positionResult
        case let .failed(error): return .failed(error)
        case .pending: return .pending
        }
    }

    /// A vanished position never confirms: a liquidation racing the margin
    /// change is a different outcome and must not read as success.
    func reconcileMarginChange(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        await reconcile(pending, label: "marginChange") { positions in
            guard let marginChange = pending.marginChange else { return false }
            guard let current = positions.first(where: { $0.marketId == pending.marketId }) else {
                return false
            }
            return PerpsChangeSettlement.marginMoved(
                current: current.marginUsd,
                before: marginChange.allocatedMarginBefore,
                amountUsd: marginChange.amountUsd,
                direction: marginChange.direction
            )
        }
    }

    func recoverInterruptedOperations() async {
        guard !Task.isCancelled else { return }
        do {
            guard let session = try await activationService.tradingSession(wallet: wallet) else { return }
            guard !Task.isCancelled else { return }
            try await recoverInterruptedOperations(
                wallet: wallet,
                session: session,
                excluding: nil
            )
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: background operation recovery paused — \(mapped)")
        }
    }

    func previewLiquidation(
        side: PerpsTradeSide,
        marginUsd: Double,
        leverage: Double,
        openingFeeRate: Double,
        entryPrice: Double,
        markPrice: Double,
        maintenanceFraction: Double
    ) -> PerpsLiquidationPreview {
        guard entryPrice > 0 else {
            return PerpsLiquidationPreview(price: nil, isImmediateRisk: false, unavailableReason: .missingMark)
        }
        let baseSize = (marginUsd * leverage) / entryPrice
        let openingFeeUsd = marginUsd * leverage * max(openingFeeRate, 0)
        return previewPositionLiquidation(
            side: side,
            baseSize: baseSize,
            entryPrice: entryPrice,
            markPrice: markPrice,
            maintenanceFraction: maintenanceFraction,
            collateralUsd: marginUsd - openingFeeUsd
        )
    }

    func previewPositionLiquidation(
        side: PerpsTradeSide,
        baseSize: Double,
        entryPrice: Double,
        markPrice: Double,
        maintenanceFraction: Double,
        collateralUsd: Double
    ) -> PerpsLiquidationPreview {
        let estimate = LighterRisk.shared.isolatedLiquidation(
            side: PerpsTradeSideMapper.toChainKit(side),
            baseSize: baseSize,
            entryPrice: entryPrice,
            markPrice: markPrice,
            maintenanceFraction: maintenanceFraction,
            collateralUsd: collateralUsd
        )
        return PerpsLiquidationPreview(
            price: estimate.price?.doubleValue,
            isImmediateRisk: estimate.isImmediateRisk,
            unavailableReason: estimate.price == nil
                ? PerpsLiquidationReasonMapper.map(estimate.unavailableReason)
                : nil
        )
    }
}

private extension LighterPerpsTradingService {
    struct OpenOrderRequest {
        let marginUsd: Double
        let notionalUsd: Double
        let chainKitIntent: ChainKitOpenOrderIntent
    }

    enum ChainKitOpenOrderIntent {
        case limit(OpenLimitIntent)
        case market(OpenMarketIntent)
    }

    func marketMeta(wallet: Wallet, marketId: Int64) async throws -> LighterMarketMeta? {
        guard let session = try await activationService.tradingSession(wallet: wallet) else { return nil }
        return try await bridgeKotlinOptional { session.trading.marketMeta(marketId: marketId, completionHandler: $0) }
    }

    func makeOpenOrderRequest(intent: PerpsOpenMarketIntent) async -> OpenOrderRequest? {
        guard let notionalUsd = notional(marginUsd: intent.marginUsd, leverage: intent.leverage),
              notionalUsd > 0
        else {
            return nil
        }
        let marginUsdValue = decimalDouble(intent.marginUsd) ?? 0
        let markPriceArg = await markPriceProvider(intent.marketId).map { KotlinDouble(value: $0) }
        let side = PerpsTradeSideMapper.toChainKit(intent.side)
        let amount = LighterAmountQuote(usd: notionalUsd)
        let autoClose = tpSl(from: intent.autoClose)
        let chainKitIntent: ChainKitOpenOrderIntent
        if let limitPrice = intent.limitPrice, limitPrice > 0 {
            chainKitIntent = .limit(OpenLimitIntent(
                marketId: intent.marketId,
                side: side,
                amount: amount,
                limitPrice: limitPrice,
                postOnly: false,
                tpSl: autoClose,
                orderExpiry: nil,
                clientOrderIndex: 0,
                markPrice: markPriceArg,
                marginUsd: KotlinDouble(value: marginUsdValue)
            ))
        } else {
            chainKitIntent = .market(OpenMarketIntent(
                marketId: intent.marketId,
                side: side,
                amount: amount,
                maxSlippage: intent.maxSlippage,
                tpSl: autoClose,
                clientOrderIndex: 0,
                markPrice: markPriceArg,
                marginUsd: KotlinDouble(value: marginUsdValue)
            ))
        }
        return OpenOrderRequest(
            marginUsd: marginUsdValue,
            notionalUsd: notionalUsd,
            chainKitIntent: chainKitIntent
        )
    }

    func resolveSession(
        wallet: Wallet,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Result<LighterSession, PerpsTradingError> {
        do {
            if let session = try await activationService.tradingSession(wallet: wallet) {
                return .success(session)
            }
        } catch {
            return .failure(PerpsTradingErrorMapper.map(error))
        }

        guard let passcode = await passcodeProvider() else {
            return .failure(.activationCanceled)
        }
        let outcome = await activationService.activate(wallet: wallet, passcode: passcode)
        switch outcome {
        case .active:
            do {
                if let session = try await activationService.tradingSession(wallet: wallet) {
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

    func positionLeverage(_ position: LighterOpenPosition) -> Double? {
        if let leverage = position.leverage?.doubleValue { return leverage }
        guard position.allocatedMargin > 0 else { return nil }
        return abs(position.size) * position.avgEntryPrice / position.allocatedMargin
    }

    func leverageNeedsUpdate(position: LighterOpenPosition?, leverage: Double) -> Bool {
        guard let position else { return true }
        let isIsolated = Int32(position.marginMode) == LighterConstants.shared.IsolatedMargin
        let currentLeverage = position.leverage?.doubleValue
        let sameLeverage = currentLeverage.map { abs($0 - leverage) < 0.0001 } ?? false
        return !(isIsolated && sameLeverage)
    }

    func tpSl(from autoClose: PerpsAutoClose?) -> LighterTpSl? {
        guard let autoClose, !autoClose.isEmpty else { return nil }
        return LighterTpSl(
            takeProfit: autoClose.takeProfit.map {
                LighterAutoClose(
                    triggerPrice: $0.triggerPrice,
                    maxSlippage: config.maxSlippage
                )
            },
            stopLoss: autoClose.stopLoss.map {
                LighterAutoClose(
                    triggerPrice: $0.triggerPrice,
                    maxSlippage: config.maxSlippage
                )
            }
        )
    }

    func reconcile(
        _ pending: PerpsPendingTradingAction,
        label: String,
        resolveOperation: Bool = true,
        isConfirmed: ([PerpsPositionSummary]) -> Bool
    ) async -> PerpsReconcileResult {
        guard wallet.id == pending.walletId else {
            return .pending
        }
        let status = await activationService.status(wallet: wallet)
        let accountIndex: Int64
        switch status {
        case let .active(index, _), let .accountExists(index): accountIndex = index
        default: return .pending
        }
        do {
            guard let portfolio = try await activationService.portfolio(wallet: wallet, accountIndex: accountIndex) else {
                return .pending
            }
            let positions = portfolio.positions.compactMap(PerpsPositionSummary.init(position:))
            if isConfirmed(positions) {
                if resolveOperation,
                   !(await resolveSucceeded(pending, wallet: wallet))
                {
                    return .pending
                }
                Log.i("🪵 Perps: reconcile(\(label)) confirmed market=\(pending.marketId) side=\(pending.side)")
                return .confirmed(positions: positions, availableBalance: portfolio.availableBalance)
            }
            if let rejected = try await canceledPrimaryOrder(
                pending,
                wallet: wallet,
                accountIndex: accountIndex
            ) {
                guard await resolveFailed(pending, wallet: wallet, message: rejected.status) else {
                    return .pending
                }
                return .failed(.serverRejected(rejected.status))
            }
            Log.i("🪵 Perps: reconcile(\(label)) still pending market=\(pending.marketId) side=\(pending.side)")
            return .pending
        } catch {
            Log.w("🪵 Perps: reconcile(\(label)) read failed market=\(pending.marketId) — \(error)")
            return .pending
        }
    }

    /// Client-order indexes are ordered exactly as the signed transaction. The
    /// first non-empty step's first index is the primary position/order leg;
    /// grouped TP/SL children follow it and must never confirm the parent action.
    func operationOrderIndexes(
        _ pending: PerpsPendingTradingAction,
        wallet: Wallet
    ) async throws -> [Int64] {
        guard let session = try await activationService.tradingSession(wallet: wallet),
              let operation: LighterOperation = try await bridgeKotlinOptional({
                  session.operations.operation(operationId: pending.operationId, completionHandler: $0)
              })
        else {
            return []
        }
        return operation.steps.flatMap { step in
            step.clientOrderIndexes.map(\.int64Value)
        }
    }

    func canceledPrimaryOrder(
        _ pending: PerpsPendingTradingAction,
        wallet: Wallet,
        accountIndex: Int64
    ) async throws -> PerpsOrder? {
        guard let clientOrderIndex = try await operationOrderIndexes(pending, wallet: wallet).first else {
            return nil
        }
        let inactive = try await activationService.inactiveOrders(
            wallet: wallet,
            accountIndex: accountIndex,
            marketId: pending.marketId
        )
        return inactive.first {
            $0.clientOrderIndex == clientOrderIndex && $0.isExecutionRejected
        }
    }

    func resolveSucceeded(_ pending: PerpsPendingTradingAction, wallet: Wallet) async -> Bool {
        do {
            guard let session = try await activationService.tradingSession(wallet: wallet) else {
                return false
            }
            let _: LighterOperation = try await bridgeKotlin { completion in
                session.operations.resolve(
                    operationId: pending.operationId,
                    resolution: LighterOperationResolution.succeeded,
                    failureMessage: nil,
                    completionHandler: completion
                )
            }
            try? await activationService.operationStore(wallet: wallet)
                .removePending(operationId: pending.operationId)
            return true
        } catch {
            Log.w("🪵 Perps: operation resolve failed id=\(pending.operationId) — \(error)")
            return false
        }
    }

    func resolveFailed(_ pending: PerpsPendingTradingAction, wallet: Wallet, message: String) async -> Bool {
        do {
            guard let session = try await activationService.tradingSession(wallet: wallet) else {
                return false
            }
            let _: LighterOperation = try await bridgeKotlin { completion in
                session.operations.resolve(
                    operationId: pending.operationId,
                    resolution: LighterOperationResolution.failed,
                    failureMessage: message,
                    completionHandler: completion
                )
            }
            try? await activationService.operationStore(wallet: wallet)
                .removePending(operationId: pending.operationId)
            return true
        } catch {
            Log.w("🪵 Perps: operation failure resolve failed id=\(pending.operationId) — \(error)")
            return false
        }
    }

    struct Submission {
        let pending: PerpsPendingTradingAction
        let execute: () async throws -> LighterOperation
    }

    func submitOpenMarket(_ prepared: PerpsPreparedTradingAction) async -> PerpsSubmitResult {
        await submitAction(
            operationId: prepared.operationId,
            walletId: prepared.walletId,
            isTestnet: prepared.isTestnet,
            marketId: prepared.marketId
        ) { _, session in
            guard let request = await self.makeOpenOrderRequest(intent: prepared.intent) else {
                throw PerpsTradingError.validation("amount is empty or invalid")
            }
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                session.trading.currentPosition(marketId: prepared.marketId, completionHandler: $0)
            }
            let needsLeverage = self.leverageNeedsUpdate(position: position, leverage: prepared.intent.leverage)
            let leverage: KotlinDouble? = needsLeverage ? KotlinDouble(value: prepared.intent.leverage) : nil
            let execute: () async throws -> LighterOperation
            switch request.chainKitIntent {
            case let .limit(intent):
                execute = {
                    try await bridgeKotlin { completion in
                        session.trading.executeOpenLimit(
                            operationId: prepared.operationId,
                            intent: intent,
                            leverage: leverage,
                            marginMode: LighterConstants.shared.IsolatedMargin,
                            completionHandler: completion
                        )
                    }
                }
            case let .market(intent):
                execute = {
                    try await bridgeKotlin { completion in
                        session.trading.executeOpenMarket(
                            operationId: prepared.operationId,
                            intent: intent,
                            leverage: leverage,
                            marginMode: LighterConstants.shared.IsolatedMargin,
                            completionHandler: completion
                        )
                    }
                }
            }
            return Submission(
                pending: PerpsPendingTradingAction(
                    operationId: prepared.operationId,
                    kind: .open,
                    walletId: prepared.walletId,
                    isTestnet: prepared.isTestnet,
                    marketId: prepared.marketId,
                    side: prepared.intent.side,
                    limitPrice: prepared.intent.limitPrice,
                    positionBaseSizeBefore: position.flatMap {
                        PerpsTradeSideMapper.fromChainKit($0.side) == prepared.intent.side ? abs($0.size) : nil
                    }
                ),
                execute: execute
            )
        }
    }

    func submitClose(_ prepared: PerpsPreparedCloseAction) async -> PerpsSubmitResult {
        await submitAction(
            operationId: prepared.operationId,
            walletId: prepared.walletId,
            isTestnet: prepared.isTestnet,
            marketId: prepared.marketId
        ) { _, session in
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                session.trading.currentPosition(marketId: prepared.marketId, completionHandler: $0)
            }
            guard let position else { throw PerpsTradingError.positionNotFound }
            guard PerpsTradeSideMapper.fromChainKit(position.side) == prepared.review.side else {
                throw PerpsTradingError.stalePreparedTransaction
            }
            let markPrice = await self.markPriceProvider(prepared.marketId).map { KotlinDouble(value: $0) }
            let intent = CloseIntent(
                marketId: prepared.marketId,
                portion: 1,
                maxSlippage: self.config.closeMaxSlippage,
                clientOrderIndex: 0,
                markPrice: markPrice
            )
            return Submission(
                pending: PerpsPendingTradingAction(
                    operationId: prepared.operationId,
                    kind: .close,
                    walletId: prepared.walletId,
                    isTestnet: prepared.isTestnet,
                    marketId: prepared.marketId,
                    side: prepared.review.side,
                    positionBaseSizeBefore: abs(position.size)
                ),
                execute: {
                    try await bridgeKotlin { completion in
                        session.trading.executeClose(
                            operationId: prepared.operationId,
                            intent: intent,
                            completionHandler: completion
                        )
                    }
                }
            )
        }
    }

    func submitSizeChange(_ prepared: PerpsPreparedSizeChangeAction) async -> PerpsSubmitResult {
        await submitAction(
            operationId: prepared.operationId,
            walletId: prepared.walletId,
            isTestnet: prepared.isTestnet,
            marketId: prepared.marketId
        ) { wallet, session in
            guard let marginDelta = self.decimalDouble(prepared.intent.marginDeltaUsd), marginDelta > 0 else {
                throw PerpsTradingError.validation("amount is empty or invalid")
            }
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                session.trading.currentPosition(marketId: prepared.marketId, completionHandler: $0)
            }
            guard let position, abs(position.size) > 0 else {
                throw PerpsTradingError.positionNotFound
            }

            var replacement: LighterTpSl?
            var indexesToCancel: [Int64] = []
            var pendingAutoClose: PerpsPendingAutoCloseChange?
            switch prepared.intent.autoCloseUpdate {
            case .unchanged:
                break
            case .clear, .replace:
                let target: PerpsAutoClose
                if case .clear = prepared.intent.autoCloseUpdate {
                    target = PerpsAutoClose(takeProfit: nil, stopLoss: nil)
                } else if let normalized = prepared.normalizedAutoClose {
                    target = normalized
                } else {
                    throw PerpsTradingError.validation("auto-close preview is unavailable")
                }
                let resting = try await self.activationService.activeTriggerOrders(
                    wallet: wallet,
                    accountIndex: session.accountIndex,
                    marketId: prepared.marketId
                )
                switch PerpsAutoCloseChangePlanner.plan(target: target, resting: resting) {
                case .noChange:
                    break
                case let .replace(normalized, staleOrderIndexes):
                    guard let tpSl = self.tpSl(from: normalized) else {
                        throw PerpsTradingError.validation("auto-close target is empty")
                    }
                    replacement = tpSl
                    indexesToCancel = staleOrderIndexes
                    pendingAutoClose = PerpsPendingAutoCloseChange(
                        target: normalized,
                        restingOrderIndexes: staleOrderIndexes
                    )
                case let .clear(orderIndexes):
                    indexesToCancel = orderIndexes
                    pendingAutoClose = PerpsPendingAutoCloseChange(
                        target: nil,
                        restingOrderIndexes: orderIndexes
                    )
                }
            }

            let execute: () async throws -> LighterOperation
            let markPrice = await self.markPriceProvider(prepared.marketId).map { KotlinDouble(value: $0) }
            switch prepared.intent.direction {
            case .add:
                guard let leverage = self.positionLeverage(position), leverage > 0 else {
                    throw PerpsTradingError.validation("position leverage unavailable")
                }
                execute = {
                    try await bridgeKotlin { completion in
                        session.trading.executeAddToPosition(
                            operationId: prepared.operationId,
                            marketId: prepared.marketId,
                            amount: LighterAmountQuote(usd: marginDelta * leverage),
                            maxSlippage: self.config.maxSlippage,
                            markPrice: markPrice,
                            marginUsd: KotlinDouble(value: marginDelta),
                            tpSl: replacement,
                            orderIndexesToCancel: indexesToCancel.map { KotlinLong(value: $0) },
                            completionHandler: completion
                        )
                    }
                }
            case .reduce:
                guard position.allocatedMargin > 0, marginDelta < position.allocatedMargin else {
                    throw PerpsTradingError.validation("amount exceeds position margin")
                }
                execute = {
                    try await bridgeKotlin { completion in
                        session.trading.executeReducePosition(
                            operationId: prepared.operationId,
                            marketId: prepared.marketId,
                            portion: marginDelta / position.allocatedMargin,
                            maxSlippage: self.config.closeMaxSlippage,
                            markPrice: markPrice,
                            tpSl: replacement,
                            orderIndexesToCancel: indexesToCancel.map { KotlinLong(value: $0) },
                            completionHandler: completion
                        )
                    }
                }
            }

            return Submission(
                pending: PerpsPendingTradingAction(
                    operationId: prepared.operationId,
                    kind: .sizeChange,
                    walletId: prepared.walletId,
                    isTestnet: prepared.isTestnet,
                    marketId: prepared.marketId,
                    side: PerpsTradeSideMapper.fromChainKit(position.side),
                    sizeChange: PerpsPendingSizeChange(
                        direction: prepared.intent.direction,
                        baseSizeBefore: abs(position.size)
                    ),
                    autoCloseChange: pendingAutoClose
                ),
                execute: execute
            )
        }
    }

    func submitMarginChange(_ prepared: PerpsPreparedMarginChangeAction) async -> PerpsSubmitResult {
        await submitAction(
            operationId: prepared.operationId,
            walletId: prepared.walletId,
            isTestnet: prepared.isTestnet,
            marketId: prepared.marketId
        ) { _, session in
            guard let amount = self.decimalDouble(prepared.intent.amountUsd), amount > 0 else {
                throw PerpsTradingError.validation("amount is empty or invalid")
            }
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                session.trading.currentPosition(marketId: prepared.marketId, completionHandler: $0)
            }
            guard let position, abs(position.size) > 0 else {
                throw PerpsTradingError.positionNotFound
            }
            if prepared.intent.direction == .reduce, amount >= position.allocatedMargin {
                throw PerpsTradingError.validation("amount exceeds position margin")
            }
            let markPrice = await self.markPriceProvider(prepared.marketId).map { KotlinDouble(value: $0) }
            let direction: LighterMarginDirection
            switch prepared.intent.direction {
            case .add:
                direction = LighterMarginDirection.add
            case .reduce:
                let review: LighterMarginReview = try await bridgeKotlin { completion in
                    session.trading.previewReduceMargin(
                        marketId: prepared.marketId,
                        usdc: amount,
                        markPrice: markPrice,
                        completionHandler: completion
                    )
                }
                if review.isImmediateRisk {
                    throw PerpsTradingError.immediateLiquidationRisk
                }
                direction = LighterMarginDirection.remove
            }
            return Submission(
                pending: PerpsPendingTradingAction(
                    operationId: prepared.operationId,
                    kind: .marginChange,
                    walletId: prepared.walletId,
                    isTestnet: prepared.isTestnet,
                    marketId: prepared.marketId,
                    side: PerpsTradeSideMapper.fromChainKit(position.side),
                    marginChange: PerpsPendingMarginChange(
                        direction: prepared.intent.direction,
                        allocatedMarginBefore: position.allocatedMargin,
                        amountUsd: amount
                    )
                ),
                execute: {
                    try await bridgeKotlin { completion in
                        session.trading.executeMarginUpdate(
                            operationId: prepared.operationId,
                            marketId: prepared.marketId,
                            usdc: amount,
                            direction: direction,
                            markPrice: markPrice,
                            completionHandler: completion
                        )
                    }
                }
            )
        }
    }

    func submitAutoCloseChange(_ prepared: PerpsPreparedAutoCloseChangeAction) async -> PerpsSubmitResult {
        await submitAction(
            operationId: prepared.operationId,
            walletId: prepared.walletId,
            isTestnet: prepared.isTestnet,
            marketId: prepared.marketId
        ) { wallet, session in
            let position: LighterOpenPosition? = try await bridgeKotlinOptional {
                session.trading.currentPosition(marketId: prepared.marketId, completionHandler: $0)
            }
            guard let position, abs(position.size) > 0 else {
                throw PerpsTradingError.positionNotFound
            }
            let resting = try await self.activationService.activeTriggerOrders(
                wallet: wallet,
                accountIndex: session.accountIndex,
                marketId: prepared.marketId
            )

            let replacement: LighterTpSl?
            let indexesToCancel: [Int64]
            let target: PerpsAutoClose?
            let normalizedTarget = prepared.review.new
                ?? PerpsAutoClose(takeProfit: nil, stopLoss: nil)
            switch PerpsAutoCloseChangePlanner.plan(target: normalizedTarget, resting: resting) {
            case .noChange:
                throw PerpsTradingError.nothingToChange
            case let .replace(normalized, staleOrderIndexes):
                guard let tpSl = self.tpSl(from: normalized) else {
                    throw PerpsTradingError.validation("auto-close target is empty")
                }
                replacement = tpSl
                indexesToCancel = staleOrderIndexes
                target = prepared.review.new
            case let .clear(orderIndexes):
                replacement = nil
                indexesToCancel = orderIndexes
                target = nil
            }

            return Submission(
                pending: PerpsPendingTradingAction(
                    operationId: prepared.operationId,
                    kind: .autoCloseChange,
                    walletId: prepared.walletId,
                    isTestnet: prepared.isTestnet,
                    marketId: prepared.marketId,
                    side: PerpsTradeSideMapper.fromChainKit(position.side),
                    autoCloseChange: PerpsPendingAutoCloseChange(
                        target: target,
                        restingOrderIndexes: indexesToCancel
                    )
                ),
                execute: {
                    try await bridgeKotlin { completion in
                        session.trading.executeTpSlChange(
                            operationId: prepared.operationId,
                            marketId: prepared.marketId,
                            tpSl: replacement,
                            orderIndexesToCancel: indexesToCancel.map { KotlinLong(value: $0) },
                            completionHandler: completion
                        )
                    }
                }
            )
        }
    }

    func submitLimitOrderChange(_ prepared: PerpsPreparedLimitOrderChangeAction) async -> PerpsSubmitResult {
        await submitAction(
            operationId: prepared.operationId,
            walletId: prepared.walletId,
            isTestnet: prepared.isTestnet,
            marketId: prepared.marketId
        ) { wallet, session in
            guard let order = try await self.activeLimitOrder(
                wallet: wallet,
                accountIndex: session.accountIndex,
                marketId: prepared.marketId,
                orderIndex: prepared.intent.orderIndex
            ), PerpsLimitOrderChangeSettlement.pricesMatch(
                order.limitPrice,
                prepared.review.order.limitPrice
            ) else {
                throw PerpsTradingError.stalePreparedTransaction
            }

            let execute: () async throws -> LighterOperation
            switch prepared.review.kind {
            case .modify:
                guard let limitPrice = prepared.review.limitPrice else {
                    throw PerpsTradingError.validation("normalized limit price is unavailable")
                }
                execute = {
                    try await bridgeKotlin { completion in
                        session.trading.executeModifyLimitOrder(
                            operationId: prepared.operationId,
                            intent: ModifyLimitOrderIntent(
                                marketId: prepared.marketId,
                                orderIndex: order.orderIndex,
                                limitPrice: limitPrice,
                                size: nil
                            ),
                            completionHandler: completion
                        )
                    }
                }
            case .cancel:
                execute = {
                    try await bridgeKotlin { completion in
                        session.trading.executeCancelOrder(
                            operationId: prepared.operationId,
                            marketId: prepared.marketId,
                            orderIndex: order.orderIndex,
                            completionHandler: completion
                        )
                    }
                }
            }

            return Submission(
                pending: PerpsPendingTradingAction(
                    operationId: prepared.operationId,
                    kind: .limitOrderChange,
                    walletId: prepared.walletId,
                    isTestnet: prepared.isTestnet,
                    marketId: prepared.marketId,
                    side: order.side,
                    limitOrderChange: PerpsPendingLimitOrderChange(
                        orderIndex: order.orderIndex,
                        kind: prepared.review.kind,
                        limitPrice: prepared.review.limitPrice
                    )
                ),
                execute: execute
            )
        }
    }

    func submitAction(
        operationId: String,
        walletId: String,
        isTestnet: Bool,
        marketId: Int64,
        build: (Wallet, LighterSession) async throws -> Submission
    ) async -> PerpsSubmitResult {
        guard wallet.id == walletId, activationService.isTestnet == isTestnet else {
            Log.w("🪵 Perps: submit stale — wallet/env changed (market=\(marketId))")
            return .failed(.stalePreparedTransaction)
        }

        let session: LighterSession
        do {
            guard let resolved = try await activationService.tradingSession(wallet: wallet) else {
                return .failed(.activationRequired)
            }
            session = resolved
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: submit session failed before signing \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        do {
            try await recoverInterruptedOperations(
                wallet: wallet,
                session: session,
                excluding: operationId
            )
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: unresolved operation blocks submit \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        let submission: Submission
        do {
            submission = try await build(wallet, session)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: submit prepare failed before network submit \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        let store = activationService.operationStore(wallet: wallet)
        let pending: PerpsPendingTradingAction
        do {
            pending = try await store.savePendingIfAbsent(submission.pending)
        } catch {
            let mapped = PerpsTradingErrorMapper.map(error)
            Log.w("🪵 Perps: pending journal failed before signing \(mapped) (market=\(marketId))")
            return .failed(mapped)
        }

        Log.i("🪵 Perps: submit start operation=\(pending.operationId) market=\(marketId)")
        do {
            _ = try await submission.execute()
            Log.i("🪵 Perps: submit accepted operation=\(pending.operationId) market=\(marketId)")
            return .submitted(pending)
        } catch {
            let operation: LighterOperation? = try? await bridgeKotlinOptional {
                session.operations.operation(operationId: pending.operationId, completionHandler: $0)
            }
            if let operation, operation.state !== LighterOperationState.failed {
                Log.w("🪵 Perps: submit outcome unknown operation=\(pending.operationId) state=\(operation.state)")
                return .submitUnknown(pending)
            }
            if let blocked = PerpsTradingErrorMapper.operationBlockedException(from: error),
               blocked.blockingOperationId == pending.operationId
            {
                return .submitUnknown(pending)
            }
            try? await store.removePending(operationId: pending.operationId)
            let mapped: PerpsTradingError
            if let failure = operation?.failure {
                mapped = PerpsTradingErrorMapper.map(failure)
            } else {
                mapped = PerpsTradingErrorMapper.map(error)
            }
            Log.w("🪵 Perps: submit failed \(mapped) operation=\(pending.operationId) market=\(marketId)")
            return .failed(mapped)
        }
    }

    func recoverInterruptedOperations(
        wallet: Wallet,
        session: LighterSession,
        excluding operationId: String?
    ) async throws {
        let store = activationService.operationStore(wallet: wallet)
        try await store.cleanupPending()
        let operations: [LighterOperation] = try await bridgeKotlin { completion in
            session.operations.unresolvedOperations(completionHandler: completion)
        }
        for operation in operations {
            if let operationId, operation.operationId == operationId { continue }
            let resumed: LighterOperation
            do {
                resumed = try await bridgeKotlin { completion in
                    session.operations.resume(operationId: operation.operationId, completionHandler: completion)
                }
            } catch {
                let current: LighterOperation? = try? await bridgeKotlinOptional {
                    session.operations.operation(operationId: operation.operationId, completionHandler: $0)
                }
                if let current, current.state === LighterOperationState.failed {
                    try? await store.removePending(operationId: operation.operationId)
                    continue
                }
                throw PerpsTradingError.operationInProgress
            }

            guard let pending = try await store.pending(operationId: operation.operationId) else {
                if !resumed.isTerminal {
                    throw PerpsTradingError.operationInProgress
                }
                continue
            }
            _ = await reconcilePersisted(pending)
            let current: LighterOperation? = try? await bridgeKotlinOptional {
                session.operations.operation(operationId: operation.operationId, completionHandler: $0)
            }
            if current?.isTerminal != true {
                throw PerpsTradingError.operationInProgress
            }
        }
    }

    func reconcilePersisted(_ pending: PerpsPendingTradingAction) async -> Bool {
        switch pending.kind {
        case .open:
            if case .confirmed = await reconcileOpenMarket(pending) { return true }
        case .close:
            if case .confirmed = await reconcileClose(pending) { return true }
        case .sizeChange:
            if case .confirmed = await reconcileSizeChange(pending) { return true }
        case .marginChange:
            if case .confirmed = await reconcileMarginChange(pending) { return true }
        case .autoCloseChange:
            if case .confirmed = await reconcileAutoCloseChange(pending) { return true }
        case .limitOrderChange:
            if case .confirmed = await reconcileLimitOrderChange(pending) { return true }
        }
        return false
    }

    func activeLimitOrder(
        wallet: Wallet,
        accountIndex: Int64,
        marketId: Int64,
        orderIndex: Int64
    ) async throws -> PerpsLimitOrderSummary? {
        try await activationService.activeOrders(
            wallet: wallet,
            accountIndex: accountIndex,
            marketId: marketId
        )
        .first(where: { $0.orderIndex == orderIndex })
        .flatMap(PerpsLimitOrderSummary.init(order:))
    }

    func notional(marginUsd: String, leverage: Double) -> Double? {
        guard let margin = decimalDouble(marginUsd), margin > 0, leverage > 0 else { return nil }
        return margin * leverage
    }

    func decimalDouble(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let decimal = Decimal(string: trimmed) else { return nil }
        return NSDecimalNumber(decimal: decimal).doubleValue
    }
}
