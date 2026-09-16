import ChainKit
import Foundation

public extension PerpsAutoClose {
    /// The first TP and SL legs of a market's resting trigger orders; nil when none.
    init?(triggerOrders: [PerpsTriggerOrderSummary]) {
        let takeProfit = triggerOrders.first { $0.kind == .takeProfit }
        let stopLoss = triggerOrders.first { $0.kind == .stopLoss }
        guard takeProfit != nil || stopLoss != nil else { return nil }
        self.init(
            takeProfit: takeProfit.map { PerpsAutoCloseTrigger(triggerPrice: $0.triggerPrice) },
            stopLoss: stopLoss.map { PerpsAutoCloseTrigger(triggerPrice: $0.triggerPrice) }
        )
    }
}

public struct PerpsTriggerOrderSummary: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case takeProfit
        case stopLoss
    }

    public let orderIndex: Int64
    /// Client order index assigned at creation; zero when the venue reports none.
    public let clientOrderIndex: Int64
    public let kind: Kind
    public let side: PerpsTradeSide
    public let triggerPrice: Double
    public let baseAmount: Double
    /// Venue expiry for this armed trigger; zero means unavailable.
    public let expiresAtSeconds: Int64

    /// Preferred `CancelOrder` identity. SDK-created position-tied triggers must
    /// use their client index because their composite read index is a venue no-op.
    /// Orders created with a nil client index can only fall back to the venue index.
    public var cancelKey: Int64 {
        clientOrderIndex > 0 ? clientOrderIndex : orderIndex
    }

    public init(
        orderIndex: Int64,
        clientOrderIndex: Int64 = 0,
        kind: Kind,
        side: PerpsTradeSide,
        triggerPrice: Double,
        baseAmount: Double,
        expiresAtSeconds: Int64 = 0
    ) {
        self.orderIndex = orderIndex
        self.clientOrderIndex = clientOrderIndex
        self.kind = kind
        self.side = side
        self.triggerPrice = triggerPrice
        self.baseAmount = baseAmount
        self.expiresAtSeconds = expiresAtSeconds
    }
}

extension PerpsTriggerOrderSummary {
    init?(order: PerpsOrder) {
        guard let kind = PerpsTriggerOrderSummary.classify(type: order.type) else { return nil }
        let triggerPrice = PerpsMarketMath.double(order.triggerPrice)
        guard triggerPrice > 0 else { return nil }
        // Position-tied TP/SL legs use a zero base amount because the venue sizes
        // them from the live position.
        let baseAmount = abs(PerpsMarketMath.double(order.remainingBaseAmount))
        self.init(
            orderIndex: order.orderIndex,
            clientOrderIndex: order.clientOrderIndex,
            kind: kind,
            side: PerpsTradeSideMapper.fromChainKit(order.side),
            triggerPrice: triggerPrice,
            baseAmount: baseAmount,
            expiresAtSeconds: order.expiresAtSeconds
        )
    }

    private static func classify(type: String) -> Kind? {
        // The venue spells order types inconsistently across deployments
        // ("take_profit", "take-profit"); compare letters only.
        let normalized = type.lowercased().filter(\.isLetter)
        if normalized.contains("takeprofit") { return .takeProfit }
        if normalized.contains("stoploss") { return .stopLoss }
        return nil
    }
}

public struct PerpsLimitOrderSummary: Equatable, Sendable {
    public let orderIndex: Int64
    public let clientOrderIndex: Int64
    public let side: PerpsTradeSide
    public let limitPrice: Double
    public let remainingBaseAmount: Double
    public let filledBaseAmount: Double
    public let expiresAtSeconds: Int64

    public init(
        orderIndex: Int64,
        clientOrderIndex: Int64,
        side: PerpsTradeSide,
        limitPrice: Double,
        remainingBaseAmount: Double,
        filledBaseAmount: Double = 0,
        expiresAtSeconds: Int64 = 0
    ) {
        self.orderIndex = orderIndex
        self.clientOrderIndex = clientOrderIndex
        self.side = side
        self.limitPrice = limitPrice
        self.remainingBaseAmount = remainingBaseAmount
        self.filledBaseAmount = filledBaseAmount
        self.expiresAtSeconds = expiresAtSeconds
    }
}

extension PerpsLimitOrderSummary {
    init?(order: PerpsOrder) {
        let type = order.type
            .lowercased()
            .filter(\.isLetter)
        guard type == "limit" || type == "limitorder",
              !order.reduceOnly,
              order.parentOrderIndex == 0
        else {
            return nil
        }
        let price = PerpsMarketMath.double(order.price)
        let remaining = abs(PerpsMarketMath.double(order.remainingBaseAmount))
        guard price > 0, remaining > 0 else { return nil }
        self.init(
            orderIndex: order.orderIndex,
            clientOrderIndex: order.clientOrderIndex,
            side: PerpsTradeSideMapper.fromChainKit(order.side),
            limitPrice: price,
            remainingBaseAmount: remaining,
            filledBaseAmount: abs(PerpsMarketMath.double(order.filledBaseAmount)),
            expiresAtSeconds: order.expiresAtSeconds
        )
    }
}

public struct PerpsActiveOrders: Equatable, Sendable {
    public let limitOrders: [PerpsLimitOrderSummary]
    public let triggerOrders: [PerpsTriggerOrderSummary]

    public init(limitOrders: [PerpsLimitOrderSummary], triggerOrders: [PerpsTriggerOrderSummary]) {
        self.limitOrders = limitOrders
        self.triggerOrders = triggerOrders
    }
}

public struct PerpsActivityItem: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case trade
        case liquidation
        case funding
        case deposit
        case withdrawal
        case other
    }

    public let id: String
    public let kind: Kind
    public let marketId: Int64?
    public let side: PerpsTradeSide?
    public let baseSize: Double?
    public let price: Double?
    public let usdAmount: Double?
    public let realizedPnl: Double?
    public let date: Date

    public enum Outcome: Equatable, Sendable {
        case opened
        case closed
        case liquidated
        case funding
        case other
    }

    public var outcome: Outcome {
        switch kind {
        case .liquidation: .liquidated
        case .trade: realizedPnl != nil ? .closed : .opened
        case .funding: .funding
        case .deposit, .withdrawal, .other: .other
        }
    }

    public init(
        id: String,
        kind: Kind,
        marketId: Int64?,
        side: PerpsTradeSide?,
        baseSize: Double?,
        price: Double?,
        usdAmount: Double?,
        realizedPnl: Double?,
        date: Date
    ) {
        self.id = id
        self.kind = kind
        self.marketId = marketId
        self.side = side
        self.baseSize = baseSize
        self.price = price
        self.usdAmount = usdAmount
        self.realizedPnl = realizedPnl
        self.date = date
    }
}

extension PerpsActivityItem {
    init(activity: PerpsActivity) {
        self.init(
            id: activity.id,
            kind: PerpsActivityItem.Kind(activity.kind),
            marketId: activity.marketId?.int64Value,
            side: activity.side.map(PerpsTradeSideMapper.fromChainKit),
            baseSize: activity.size.flatMap { PerpsMarketMath.optionalDouble($0) },
            price: activity.price.flatMap { PerpsMarketMath.optionalDouble($0) },
            usdAmount: activity.usdAmount.flatMap { PerpsMarketMath.optionalDouble($0) },
            realizedPnl: activity.realizedPnl.flatMap { PerpsMarketMath.optionalDouble($0) },
            date: Date(timeIntervalSince1970: TimeInterval(activity.timestampMillis) / 1000)
        )
    }
}

private extension PerpsActivityItem.Kind {
    init(_ kind: PerpsActivityKind) {
        if kind === PerpsActivityKind.trade { self = .trade }
        else if kind === PerpsActivityKind.liquidation { self = .liquidation }
        else if kind === PerpsActivityKind.fundingPayment { self = .funding }
        else if kind === PerpsActivityKind.deposit { self = .deposit }
        else if kind === PerpsActivityKind.withdrawal { self = .withdrawal }
        else { self = .other }
    }
}

public struct PerpsMarketExtras: Equatable, Sendable {
    public let limitOrders: [PerpsLimitOrderSummary]
    public let triggerOrders: [PerpsTriggerOrderSummary]
    public let recentActivity: [PerpsActivityItem]

    public init(
        limitOrders: [PerpsLimitOrderSummary] = [],
        triggerOrders: [PerpsTriggerOrderSummary],
        recentActivity: [PerpsActivityItem]
    ) {
        self.limitOrders = limitOrders
        self.triggerOrders = triggerOrders
        self.recentActivity = recentActivity
    }
}
