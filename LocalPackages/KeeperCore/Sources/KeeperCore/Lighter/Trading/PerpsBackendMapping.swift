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
            liquidationDistancePercent: PerpsMarketMath.optionalDouble(position.liquidation_distance_pct),
            markPrice: PerpsMarketMath.optionalDouble(position.mark_price)
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

    /// Entering a position waits for the venue's yes, as the screen's button does
    /// (`PerpsTradingFlags.canOpen`); the refusal reads as this market being unavailable.
    static func openEnabled(_ flags: Components.Schemas.TradingFlags?) -> Bool {
        flags?.open_enabled ?? false
    }

    static func tradingFlags(_ screen: Components.Schemas.TradingScreen) -> PerpsTradingFlags? {
        guard let flags = screen.flags else { return nil }
        let holdsPosition = screen.position != nil
        return PerpsTradingFlags(
            openEnabled: flags.open_enabled,
            closeEnabled: holdsPosition ? flags.close_enabled : nil,
            cancelEnabled: flags.cancel_enabled,
            addMarginEnabled: holdsPosition ? flags.add_margin_enabled : nil,
            removeMarginEnabled: holdsPosition ? flags.remove_margin_enabled : nil,
            autoCloseEnabled: flags.auto_close_enabled
        )
    }

    static func limitOrders(
        _ orders: [Components.Schemas.Order]?,
        market: Components.Schemas.Market? = nil
    ) -> [PerpsLimitOrderSummary] {
        (orders ?? []).compactMap { order in
            guard var summary = limitOrder(order) else { return nil }
            summary.isBelowMarketMinimum = isBelowMinimum(order, market: market)
            return summary
        }
    }

    static func portfolioOrders(_ orders: [Components.Schemas.PortfolioOrder]?) -> [PerpsPortfolioOrder] {
        (orders ?? []).compactMap { item in
            let order = item.value1
            guard let marketId = order.market_index.map(Int64.init),
                  let symbol = order.symbol, !symbol.isEmpty,
                  let summary = restingOrder(order)
            else { return nil }
            return PerpsPortfolioOrder(
                marketId: marketId,
                symbol: symbol,
                order: summary,
                marginUsd: PerpsMarketMath.optionalDouble(item.value2.margin),
                leverage: leverage(item.value2.leverage)
            )
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

    static func autoCloseLegs(of order: Components.Schemas.Order) -> [PerpsTriggerOrderSummary] {
        let closingSide: PerpsTradeSide = tradeSide(order.side ?? .long) == .long ? .short : .long
        let legs: [(Components.Schemas.OrderAutoCloseLeg?, PerpsTriggerOrderSummary.Kind)] = [
            (order.auto_close?.value1.take_profit?.value1, .takeProfit),
            (order.auto_close?.value1.stop_loss?.value1, .stopLoss),
        ]
        return legs.compactMap { leg, kind in
            leg.flatMap { triggerOrder(leg: $0, kind: kind, side: closingSide) }
        }
    }

    static func autoCloseLeg(_ orders: [Components.Schemas.Order]?, key: Int64) -> PerpsLimitOrderSummary? {
        let leg = (orders ?? []).lazy
            .flatMap(autoCloseLegs(of:))
            .first { $0.orderIndex == key || ($0.clientOrderIndex != 0 && $0.clientOrderIndex == key) }
        return leg.map {
            PerpsLimitOrderSummary(
                orderIndex: $0.orderIndex,
                clientOrderIndex: $0.clientOrderIndex,
                side: $0.side,
                limitPrice: $0.triggerPrice,
                remainingBaseAmount: $0.baseAmount,
                expiresAtSeconds: $0.expiresAtSeconds
            )
        }
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

    static func rejectionError(_ status: String) -> PerpsTradingError {
        switch status {
        case PerpsTkReconcile.orderFilled: .orderFilledBeforeCancel
        case PerpsTkReconcile.orderGone: .orderNotFound
        case PerpsTkReconcile.positionGone: .positionNotFound
        default: isSlippageCancel(status) ? .slippageExceeded : .serverRejected(status)
        }
    }

    static func changeTarget(
        _ detail: Components.Schemas.OrderDetail?,
        kind: PerpsLimitOrderChangeKind
    ) throws -> PerpsLimitOrderSummary {
        guard let order = detail?.order else { throw PerpsTradingError.orderNotFound }
        if detail?.resting == true, let resting = limitOrder(order) { return resting }
        guard kind == .cancel else { throw PerpsTradingError.orderNotFound }
        if isFilled(order) { throw PerpsTradingError.orderFilledBeforeCancel }
        throw isCanceled(order) || isRejected(order) ? PerpsTradingError.nothingToChange : PerpsTradingError.orderNotFound
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
    static func isBelowMinimum(_ order: Components.Schemas.Order, market: Components.Schemas.Market?) -> Bool {
        guard let market else { return false }
        func decimal(_ value: String?) -> Decimal {
            value.flatMap { Decimal(string: $0) } ?? 0
        }
        let remaining = decimal(order.base_size) - decimal(order.filled_base)
        return remaining < decimal(market.min_size_base)
            || remaining * decimal(order.price) < decimal(market.min_size_quote)
    }

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
            expiresAtSeconds: order.expires_at.map { Int64($0.timeIntervalSince1970) } ?? 0,
            autoCloseLegs: autoCloseLegs(of: order)
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
            expiresAtSeconds: leg.valid_to ?? 0,
            projectedROIPercent: PerpsMarketMath.optionalDouble(leg.projected_roi_pct)
        )
    }

    static func triggerOrder(
        leg: Components.Schemas.OrderAutoCloseLeg,
        kind: PerpsTriggerOrderSummary.Kind,
        side: PerpsTradeSide
    ) -> PerpsTriggerOrderSummary? {
        let triggerPrice = PerpsMarketMath.double(leg.trigger_price)
        guard triggerPrice > 0, let orderIndex = leg.order_index else { return nil }
        return PerpsTriggerOrderSummary(
            orderIndex: orderIndex,
            clientOrderIndex: leg.client_order_index ?? 0,
            kind: kind,
            side: side,
            triggerPrice: triggerPrice,
            baseAmount: 0,
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

    static let orderFilled = "order_filled"
    static let orderGone = "order_gone"
    static let positionGone = "position_gone"

    /// A resting order is placed once the service reports it working under our client
    /// index; the service taking its transaction is not yet the venue holding it.
    static func open(
        state: Components.Schemas.PositionState,
        isLimit: Bool,
        expectedBaseSize: Double? = nil
    ) -> Decision {
        if isLimit {
            return orders(state.orders, confirmWorking: true)
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
            return PerpsChangeSettlement.reaches(filled, expected: expectedBaseSize) ? .confirmed : .partiallyFilled
        }
        return .pending
    }

    /// The position the service counted, when it is exactly what this open filled.
    /// An open starts on a flat market, so any other size is a count that lags or
    /// holds something else.
    static func countedOpen(state: Components.Schemas.PositionState) -> PerpsCountedPosition? {
        guard let position = state.open?.value1.position?.value1 else { return nil }
        let size = PerpsMarketMath.double(position.size)
        let entry = PerpsMarketMath.double(position.avg_entry_price)
        let filled = state.orders
            .map { PerpsMarketMath.double($0.filled_base) }
            .max() ?? 0
        guard size > 0, entry > 0,
              PerpsChangeSettlement.reaches(size, expected: filled),
              PerpsChangeSettlement.reaches(filled, expected: size)
        else { return nil }
        return PerpsCountedPosition(
            baseSize: size,
            entryPrice: entry,
            leverage: position.leverage.flatMap { $0 > 0 ? Double($0) : nil },
            isolatedMarginUsd: position.margin_mode?.value1 == .isolated
                ? PerpsMarketMath.optionalDouble(position.allocated_margin)
                : nil
        )
    }

    /// The service's open-order list can show a resting limit under our client index
    /// before its order event reaches the position state.
    static func limitOpen(
        heard: Decision,
        openOrders: [Components.Schemas.Order]?,
        clientOrderIndex: Int64
    ) -> Decision {
        guard heard == .pending, let openOrders else { return heard }
        return openOrders.contains { $0.client_order_index == clientOrderIndex } ? .confirmed : .pending
    }

    /// Only our close order, keyed by its client index, settles a close: a position the
    /// service no longer returns may be one it has not caught up with, or one that never
    /// stopped being open on the venue.
    static func close(
        state: Components.Schemas.PositionState,
        expectedBaseSize: Double? = nil
    ) -> Decision {
        guard let expectedBaseSize else {
            return orders(state.orders, confirmWorking: false)
        }
        let filled = state.orders
            .map { PerpsMarketMath.double($0.filled_base) }
            .max() ?? 0
        if filled > 0 {
            return PerpsChangeSettlement.reaches(filled, expected: expectedBaseSize) ? .confirmed : .partiallyFilled
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
    /// then the only evidence left is legs that confirmed themselves.
    static func autoCloseChange(
        legs: [Decision],
        restingMatchesTarget: Bool?
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
        return .pending
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
            if PerpsBackendMapping.isCanceled(order) || PerpsBackendMapping.isRejected(order) {
                return .confirmed
            }
            if PerpsBackendMapping.isFilled(order) {
                return .failed(orderFilled)
            }
            return .pending
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
            return isResting ? .pending : .failed(orderGone)
        }
    }

    static func limitChange(
        change: PerpsPendingLimitOrderChange,
        ordersReadable: Bool,
        matching: Components.Schemas.Order?
    ) -> Decision {
        guard ordersReadable else { return .pending }
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
        case .cancel: return .pending
        case .modify: return .failed(orderGone)
        }
    }

    static func sizeChange(
        state: Components.Schemas.PositionState,
        expectedBaseDelta: Double?
    ) -> Decision? {
        let filled = state.orders
            .map { PerpsMarketMath.double($0.filled_base) }
            .max() ?? 0
        if let canceled = state.orders.first(where: PerpsBackendMapping.isCanceled) {
            return filled > 0 ? .partiallyFilled : .failed(canceled.status)
        }
        if let expectedBaseDelta {
            if PerpsChangeSettlement.reaches(filled, expected: expectedBaseDelta) {
                return .confirmed
            }
            return filled > 0 ? .partiallyFilled : .pending
        }
        return state.orders.contains(where: PerpsBackendMapping.isFilled) ? nil : .pending
    }

    static func sizeChange(_ change: PerpsPendingSizeChange, currentBaseSize: Double?) -> Decision {
        guard let currentBaseSize else { return .confirmed }
        return PerpsChangeSettlement.sizeMoved(
            current: currentBaseSize,
            before: change.baseSizeBefore,
            direction: change.direction,
            expectedDelta: change.expectedBaseDelta
        ) ? .confirmed : .pending
    }

    static func marginChange(
        _ change: PerpsPendingMarginChange,
        currentMarginUsd: Double?,
        canStillLand: Bool
    ) -> Decision {
        guard let currentMarginUsd else { return .failed(positionGone) }
        guard PerpsChangeSettlement.marginMoved(
            current: currentMarginUsd,
            before: change.allocatedMarginBefore,
            amountUsd: change.amountUsd,
            direction: change.direction
        ) else {
            return canStillLand ? .pending : .failed("margin_unchanged")
        }
        return .confirmed
    }

    static func withoutOrderKey(_ pending: PerpsPendingTradingAction, now: Int64) -> Decision {
        pending.hasOnlyAcceptedSignedSteps || !pending.canStillLand(now: now) ? .notSubmitted : .pending
    }

    static func withOrderKey(
        _ decision: Decision,
        orders: [Components.Schemas.PositionStateOrder],
        pending: PerpsPendingTradingAction,
        now: Int64
    ) -> Decision {
        guard decision == .pending, orders.isEmpty, !pending.canStillLand(now: now) else { return decision }
        return .notSubmitted
    }

    static func interruptedSend(_ pending: PerpsPendingTradingAction) -> PerpsPendingSignedStep? {
        pending.signedSteps?.first { $0.state == .sending }?.withState(.unknown)
    }

    static func unsentStep(_ pending: PerpsPendingTradingAction) -> PerpsPendingSignedStep? {
        pending.signedSteps?.first { $0.state == .signed }
    }

    static func refusedSendSettles(_ error: PerpsTradingError, pending: PerpsPendingTradingAction) -> Bool {
        !PerpsExecutionRelay.isAmbiguous(error)
            && (pending.orderRefs ?? []).isEmpty
            && (pending.signedSteps ?? []).allSatisfy { $0.state != .accepted }
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
