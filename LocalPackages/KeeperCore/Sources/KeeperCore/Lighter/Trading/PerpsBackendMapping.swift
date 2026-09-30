import Foundation
import TKPerpsAPI

enum PerpsAccountReadError: Error {
    case missingWalletId
}

enum PerpsBackendMapping {
    static func snapshot(
        availableBalance: String,
        positions: [Components.Schemas.OpenPosition]?
    ) -> PerpsAccountSnapshot {
        PerpsAccountSnapshot(
            availableBalance: availableBalance,
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

    static func ordersVisible(_ flags: Components.Schemas.TradingFlags?) -> Bool {
        flags?.cancel_enabled == true
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

    static func activity(_ item: Components.Schemas.ActivityItem) -> PerpsActivityItem? {
        guard let id = item.id, !id.isEmpty else { return nil }
        return PerpsActivityItem(
            id: id,
            kind: activityKind(item._type),
            marketId: item.market_index.map(Int64.init),
            side: item.side.map { tradeSide($0.value1) },
            baseSize: PerpsMarketMath.optionalDouble(item.size).map(abs),
            price: PerpsMarketMath.optionalDouble(item.price),
            usdAmount: PerpsMarketMath.optionalDouble(item.amount),
            realizedPnl: PerpsMarketMath.optionalDouble(item.realized_pnl),
            date: item.timestamp ?? Date()
        )
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
        return status == "canceled" || status == "cancelled" || status == "rejected"
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
        guard let orderIndex = order.order_index else { return nil }
        let price = PerpsMarketMath.double(order.price)
        let remaining = max(0, PerpsMarketMath.double(order.base_size) - PerpsMarketMath.double(order.filled_base))
        guard price > 0, remaining > 0 else { return nil }
        return PerpsLimitOrderSummary(
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

    static func activityKind(_ type: Components.Schemas.ActivityType?) -> PerpsActivityItem.Kind {
        switch type {
        case .fill, .tp_executed, .sl_executed: .trade
        case .liquidation: .liquidation
        case .funding: .funding
        case .deposit: .deposit
        case .withdrawal: .withdrawal
        case .none: .other
        }
    }
}

enum PerpsTkReconcile {
    enum Decision: Equatable {
        case confirmed
        case failed(String)
        case notSubmitted
        case pending
    }

    static func open(
        state: Components.Schemas.PositionState,
        isLimit: Bool,
        expectedBaseSize: Double? = nil
    ) -> Decision {
        guard !isLimit, let expectedBaseSize else {
            return orders(state.orders, confirmWorking: isLimit)
        }
        let filled = state.orders
            .map { PerpsMarketMath.double($0.filled_base) }
            .max() ?? 0
        if let canceled = state.orders.first(where: PerpsBackendMapping.isCanceled) {
            return .failed(filled > 0 ? "partial_fill" : canceled.status)
        }
        if filled > 0 {
            let tolerance = max(0.000000001, abs(expectedBaseSize) * 1e-9)
            return filled + tolerance >= expectedBaseSize ? .confirmed : .failed("partial_fill")
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
            return .failed("partial_fill")
        }
        if let canceled = state.orders.first(where: PerpsBackendMapping.isCanceled) {
            return .failed(canceled.status)
        }
        return .pending
    }

    static func sizeChange(state: Components.Schemas.PositionState) -> Decision {
        orders(state.orders, confirmWorking: false)
    }

    static func autoCloseLeg(state: Components.Schemas.PositionState) -> Decision {
        orders(state.orders, confirmWorking: true)
    }

    static func limitChange(
        change: PerpsPendingLimitOrderChange,
        ordersVisible: Bool,
        matching: Components.Schemas.Order?
    ) -> Decision {
        guard ordersVisible else { return .pending }
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
