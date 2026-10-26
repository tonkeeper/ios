import Foundation
import PerpsModels
import TKPerpsAPI

enum PerpsAccountReadError: Error {
    case missingWalletId
}

enum PerpsBackendMapping {
    static func snapshot(
        availableBalance: String,
        collateral: String? = nil,
        equity: String?,
        transferableBalance: String? = nil,
        positions: [Components.Schemas.OpenPosition]?
    ) -> PerpsAccountSnapshot {
        PerpsAccountSnapshot(
            availableBalance: availableBalance,
            collateral: collateral,
            equity: equity,
            transferableBalance: transferableBalance,
            positions: (positions ?? []).compactMap(position)
        )
    }

    static func position(_ position: Components.Schemas.OpenPosition) -> PerpsPositionSummary? {
        guard let marketId = position.market_index.map(Int64.init) else { return nil }
        let baseSize = abs(PerpsMarketMath.double(position.size))
        guard baseSize > 0 else { return nil }
        return PerpsPositionSummary(
            positionId: position.id ?? PerpsPlannerMapping.tkPositionId(marketId: marketId),
            marketId: marketId,
            symbol: position.symbol ?? "",
            side: tradeSide(position.side),
            baseSize: baseSize,
            notionalUsd: abs(PerpsMarketMath.double(position.position_value)),
            marginUsd: PerpsMarketMath.double(position.margin),
            equityUsd: PerpsMarketMath.optionalDouble(position.equity)
                ?? (PerpsMarketMath.double(position.margin) + PerpsMarketMath.double(position.unrealized_pnl)),
            leverage: leverage(position.leverage),
            roiPercent: PerpsMarketMath.optionalDouble(position.roi_pct),
            entryPrice: PerpsMarketMath.double(position.avg_entry_price),
            liquidationPrice: PerpsMarketMath.double(position.liquidation_price),
            unrealizedPnlUsd: PerpsMarketMath.double(position.unrealized_pnl),
            realizedPnlUsd: PerpsMarketMath.double(position.realized_pnl),
            fundingPaidUsd: PerpsMarketMath.optionalDouble(position.funding_paid),
            liquidationDistancePercent: PerpsMarketMath.optionalDouble(position.liquidation_distance_pct)
        )
    }

    private static func leverage(_ value: Int?) -> Double? {
        guard let value, value > 0 else { return nil }
        return Double(value)
    }

    /// Whether the order list the screen returned can be trusted. The venue answers with the
    /// list itself: without a usable read-only token it is absent, and an account that simply
    /// holds nothing on this market answers with an empty one. `cancel_enabled` is not that
    /// answer — it is derived from the orders and says only whether there is one to cancel.
    static func ordersReadable(_ screen: Components.Schemas.TradingScreen) -> Bool {
        screen.open_orders != nil
    }

    /// A flag the venue did not send is not a refusal. Deciding otherwise has the client
    /// answer for the venue, and that answer reaches the user as a statement about where
    /// they live; the venue refuses on its own when it means to. The screen still gates the
    /// button, where a person can see what is greyed out and why.
    static func openEnabled(_ flags: Components.Schemas.TradingFlags?) -> Bool {
        flags?.open_enabled ?? true
    }

    static func tradingFlags(_ flags: Components.Schemas.TradingFlags?) -> PerpsTradingFlags? {
        guard let flags else { return nil }
        return PerpsTradingFlags(
            openEnabled: flags.open_enabled,
            closeEnabled: flags.close_enabled,
            cancelEnabled: flags.cancel_enabled,
            addMarginEnabled: flags.add_margin_enabled,
            removeMarginEnabled: flags.remove_margin_enabled,
            autoCloseEnabled: flags.auto_close_enabled
        )
    }

    static func limitOrders(_ orders: [Components.Schemas.Order]?) -> [PerpsLimitOrderSummary] {
        (orders ?? []).compactMap(limitOrder)
    }

    static func portfolioOrders(_ orders: [Components.Schemas.Order]?) -> [PerpsPortfolioOrder] {
        (orders ?? []).compactMap { order in
            guard let marketId = order.market_index.map(Int64.init),
                  let symbol = order.symbol, !symbol.isEmpty,
                  let summary = restingOrder(order)
            else { return nil }
            return PerpsPortfolioOrder(marketId: marketId, symbol: symbol, order: summary)
        }
    }

    static func triggerOrders(_ orders: [Components.Schemas.Order]?) -> [PerpsTriggerOrderSummary] {
        (orders ?? []).compactMap(triggerOrder)
    }

    static func triggerOrders(
        autoClose: Components.Schemas.PositionAutoClose?,
        side: PerpsTradeSide
    ) -> [PerpsTriggerOrderSummary] {
        var orders = [PerpsTriggerOrderSummary]()
        if let takeProfit = autoClose?.take_profit?.value1,
           let order = triggerOrder(leg: takeProfit, kind: .takeProfit, side: side)
        {
            orders.append(order)
        }
        if let stopLoss = autoClose?.stop_loss?.value1,
           let order = triggerOrder(leg: stopLoss, kind: .stopLoss, side: side)
        {
            orders.append(order)
        }
        return orders
    }

    static func matchingOrder(
        _ orders: [Components.Schemas.Order],
        orderIndex: Int64
    ) -> Components.Schemas.Order? {
        orders.first { $0.order_index == orderIndex }
    }

    static func isRejected(_ order: Components.Schemas.Order) -> Bool {
        order.status == .rejected
    }

    static func isFilled(_ order: Components.Schemas.Order) -> Bool {
        order.status == .filled
    }

    static func isCanceled(_ order: Components.Schemas.Order) -> Bool {
        order.status == .canceled
    }

    static func isFilled(_ order: Components.Schemas.PositionStateOrder) -> Bool {
        order.status.lowercased() == "filled" || PerpsMarketMath.double(order.filled_base) > 0
    }

    static func isCanceled(_ order: Components.Schemas.PositionStateOrder) -> Bool {
        let status = order.status.lowercased()
        return status.hasPrefix("canceled") || status == "cancelled" || status == "rejected"
    }

    static func isSlippageCancel(_ status: String) -> Bool {
        status.lowercased().hasPrefix("canceled-too-much-slippage")
    }

    static func isWorking(_ order: Components.Schemas.PositionStateOrder) -> Bool {
        !isFilled(order) && !isCanceled(order)
    }

    static func tradeSide(_ side: Components.Schemas.PositionSide?) -> PerpsTradeSide {
        side == .short ? .short : .long
    }

    static func tradeSide(_ side: Components.Schemas.OrderSide) -> PerpsTradeSide {
        side == .short ? .short : .long
    }
}

private extension PerpsBackendMapping {
    static func limitOrder(_ order: Components.Schemas.Order) -> PerpsLimitOrderSummary? {
        guard order._type == .limit else { return nil }
        if let category = order.category, category != .open { return nil }
        if order.reduce_only == true { return nil }
        return restingOrder(order)
    }

    static func restingOrder(_ order: Components.Schemas.Order) -> PerpsLimitOrderSummary? {
        guard let orderIndex = order.order_index else { return nil }
        let price = PerpsMarketMath.double(order.price)
        let remaining = max(0, PerpsMarketMath.double(order.base_size) - PerpsMarketMath.double(order.filled_base))
        guard price > 0, remaining > 0 else { return nil }
        return PerpsLimitOrderSummary(
            id: order.id ?? "",
            orderIndex: orderIndex,
            clientOrderIndex: order.client_order_index ?? 0,
            side: tradeSide(order.side ?? .long),
            limitPrice: price,
            remainingBaseAmount: remaining,
            filledBaseAmount: PerpsMarketMath.double(order.filled_base),
            expiresAtSeconds: order.expires_at.map { Int64($0.timeIntervalSince1970) } ?? 0
        )
    }

    static func triggerOrder(_ order: Components.Schemas.Order) -> PerpsTriggerOrderSummary? {
        let kind: PerpsTriggerOrderSummary.Kind
        switch order.category {
        case .take_profit: kind = .takeProfit
        case .stop_loss: kind = .stopLoss
        default: return nil
        }
        let triggerPrice = PerpsMarketMath.double(order.trigger_price)
        guard triggerPrice > 0 else { return nil }
        guard let orderIndex = order.order_index else { return nil }
        return PerpsTriggerOrderSummary(
            orderIndex: orderIndex,
            clientOrderIndex: order.client_order_index ?? 0,
            kind: kind,
            side: tradeSide(order.side ?? .long),
            triggerPrice: triggerPrice,
            baseAmount: abs(PerpsMarketMath.double(order.base_size) - PerpsMarketMath.double(order.filled_base)),
            expiresAtSeconds: order.expires_at.map { Int64($0.timeIntervalSince1970) } ?? 0
        )
    }

    static func triggerOrder(
        leg: Components.Schemas.PositionAutoCloseLeg,
        kind: PerpsTriggerOrderSummary.Kind,
        side: PerpsTradeSide
    ) -> PerpsTriggerOrderSummary? {
        let triggerPrice = PerpsMarketMath.double(leg.trigger_price)
        guard triggerPrice > 0 else { return nil }
        let orderIndex = leg.order_index ?? 0
        return PerpsTriggerOrderSummary(
            orderIndex: orderIndex,
            clientOrderIndex: leg.client_order_index ?? 0,
            kind: kind,
            side: side,
            triggerPrice: triggerPrice,
            baseAmount: abs(PerpsMarketMath.double(leg.base_size)),
            expiresAtSeconds: leg.valid_to ?? 0
        )
    }
}

enum PerpsTkReconcile {
    enum Decision: Equatable {
        case confirmed
        case partiallyFilled
        case failed(String)
        case notSubmitted
        case pending
    }

    /// A resting order is placed the moment the venue takes its transaction; whether it
    /// fills is a later question the position answers. Waiting for the venue to also say so
    /// leaves the screen claiming "placing" for as long as the service has heard nothing —
    /// which, for an order resting far from the mark, can be its whole life.
    static func open(
        state: Components.Schemas.PositionState,
        isLimit: Bool,
        expectedBaseSize: Double? = nil,
        placementAccepted: Bool = false
    ) -> Decision {
        if isLimit {
            let heard = orders(state.orders, confirmWorking: true)
            guard case .pending = heard, placementAccepted else { return heard }
            return .confirmed
        }
        guard let expectedBaseSize else {
            return orders(state.orders, confirmWorking: false)
        }
        let filled = state.orders
            .map { PerpsMarketMath.double($0.filled_base) }
            .max() ?? 0
        if let canceled = state.orders.first(where: PerpsBackendMapping.isCanceled) {
            return filled > 0 ? .partiallyFilled : .failed(canceled.status)
        }
        if filled > 0 {
            let tolerance = max(0.000000001, abs(expectedBaseSize) * 1e-9)
            return filled + tolerance >= expectedBaseSize ? .confirmed : .partiallyFilled
        }
        return .pending
    }

    /// A prepared close carries the position size observed before submission. If the
    /// current position is absent, the user's desired state is already reached, even if
    /// another close or liquidation got there first. Without that baseline, absence is
    /// ambiguous and the order keyed by our client index remains the only evidence.
    static func close(
        state: Components.Schemas.PositionState,
        expectedBaseSize: Double? = nil
    ) -> Decision {
        if state.open == nil, expectedBaseSize != nil {
            return .confirmed
        }
        guard expectedBaseSize != nil else {
            return orders(state.orders, confirmWorking: false)
        }
        let filled = state.orders
            .map { PerpsMarketMath.double($0.filled_base) }
            .max() ?? 0
        if let expectedBaseSize,
           filled > 0,
           filled + max(0.000000001, abs(expectedBaseSize) * 1e-9) < expectedBaseSize
        {
            return .partiallyFilled
        }
        if let canceled = state.orders.first(where: PerpsBackendMapping.isCanceled) {
            return .failed(canceled.status)
        }
        return .pending
    }

    /// What the whole auto-close change came to, from what its own legs say and what
    /// the venue holds. A leg the venue refused settles it; a leg it has said nothing
    /// about does not, because a trigger order rests unheard-of until it fires, and
    /// the resting book answers for the change as a whole — including the legs it was
    /// meant to replace. `restingMatchesTarget` is nil when nothing could be read, and
    /// then the only evidence left is legs that confirmed themselves, or a venue that
    /// took every transaction this change signed.
    static func autoCloseChange(
        legs: [Decision],
        restingMatchesTarget: Bool?,
        placementAccepted: Bool
    ) -> Decision {
        if let refused = legs.first(where: { $0 != .confirmed && $0 != .pending }) {
            return refused
        }
        if let restingMatchesTarget {
            return restingMatchesTarget ? .confirmed : .pending
        }
        if !legs.isEmpty, legs.allSatisfy({ $0 == .confirmed }) {
            return .confirmed
        }
        return placementAccepted ? .confirmed : .pending
    }

    static func autoCloseLeg(state: Components.Schemas.PositionState) -> Decision {
        orders(state.orders, confirmWorking: true)
    }

    static func limitChange(
        change: PerpsPendingLimitOrderChange,
        detail: Components.Schemas.OrderDetail
    ) -> Decision {
        guard let order = detail.order else { return .pending }
        let isResting = detail.resting ?? false
        switch change.kind {
        case .cancel:
            return isResting ? .pending : .confirmed
        case .modify:
            if PerpsLimitOrderChangeSettlement.activeOrderConfirms(
                change: change,
                price: PerpsMarketMath.double(order.price)
            ) {
                return .confirmed
            }
            if PerpsBackendMapping.isRejected(order) {
                return .failed(order.status?.rawValue ?? "rejected")
            }
            return isResting ? .pending : .failed("order_gone")
        }
    }

    static func limitChange(
        change: PerpsPendingLimitOrderChange,
        ordersReadable: Bool,
        matching: Components.Schemas.Order?,
        placementAccepted: Bool
    ) -> Decision {
        guard ordersReadable else { return placementAccepted ? .confirmed : .pending }
        if let matching {
            if PerpsLimitOrderChangeSettlement.activeOrderConfirms(
                change: change,
                price: PerpsMarketMath.double(matching.price)
            ) {
                return .confirmed
            }
            if PerpsBackendMapping.isRejected(matching) {
                return .failed(matching.status?.rawValue ?? "rejected")
            }
            return .pending
        }
        switch change.kind {
        case .cancel: return .confirmed
        case .modify: return .failed("order_gone")
        }
    }
}

private extension PerpsTkReconcile {
    static func orders(
        _ orders: [Components.Schemas.PositionStateOrder],
        confirmWorking: Bool
    ) -> Decision {
        guard !orders.isEmpty else { return .pending }
        if orders.contains(where: PerpsBackendMapping.isFilled) {
            return .confirmed
        }
        if confirmWorking, orders.contains(where: PerpsBackendMapping.isWorking) {
            return .confirmed
        }
        if let canceled = orders.first(where: PerpsBackendMapping.isCanceled) {
            return .failed(canceled.status)
        }
        return .pending
    }
}
