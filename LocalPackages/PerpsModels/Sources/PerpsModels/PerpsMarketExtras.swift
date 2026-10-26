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

public struct PerpsLimitOrderSummary: Equatable, Sendable {
    public let id: String
    public let orderIndex: Int64
    public let clientOrderIndex: Int64
    public let side: PerpsTradeSide
    public let limitPrice: Double
    public let remainingBaseAmount: Double
    public let filledBaseAmount: Double
    public let expiresAtSeconds: Int64

    public init(
        id: String = "",
        orderIndex: Int64,
        clientOrderIndex: Int64,
        side: PerpsTradeSide,
        limitPrice: Double,
        remainingBaseAmount: Double,
        filledBaseAmount: Double = 0,
        expiresAtSeconds: Int64 = 0
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.clientOrderIndex = clientOrderIndex
        self.side = side
        self.limitPrice = limitPrice
        self.remainingBaseAmount = remainingBaseAmount
        self.filledBaseAmount = filledBaseAmount
        self.expiresAtSeconds = expiresAtSeconds
    }
}

public struct PerpsPortfolioOrder: Equatable, Sendable {
    public let marketId: Int64
    public let symbol: String
    public let order: PerpsLimitOrderSummary

    public init(marketId: Int64, symbol: String, order: PerpsLimitOrderSummary) {
        self.marketId = marketId
        self.symbol = symbol
        self.order = order
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

public struct PerpsTradingFlags: Equatable, Sendable {
    public let openEnabled: Bool?
    public let closeEnabled: Bool?
    public let cancelEnabled: Bool?
    public let addMarginEnabled: Bool?
    public let removeMarginEnabled: Bool?
    public let autoCloseEnabled: Bool?

    public init(
        openEnabled: Bool?,
        closeEnabled: Bool?,
        cancelEnabled: Bool?,
        addMarginEnabled: Bool?,
        removeMarginEnabled: Bool?,
        autoCloseEnabled: Bool?
    ) {
        self.openEnabled = openEnabled
        self.closeEnabled = closeEnabled
        self.cancelEnabled = cancelEnabled
        self.addMarginEnabled = addMarginEnabled
        self.removeMarginEnabled = removeMarginEnabled
        self.autoCloseEnabled = autoCloseEnabled
    }

    /// What a capability the venue said nothing about means. Entering a position is
    /// held back until it says yes: there is nothing to lose by waiting. Every way
    /// back out — closing, cancelling a resting order, moving margin, setting the
    /// triggers that close for you — is allowed unless the venue actually refuses it,
    /// because a screen that could not be read is not a reason to trap someone in a
    /// position. A refusal that is real arrives on submit, in the venue's own words.
    public var canOpen: Bool {
        openEnabled ?? false
    }

    public var canClose: Bool {
        closeEnabled ?? true
    }

    public var canCancelOrders: Bool {
        cancelEnabled ?? true
    }

    public var canAddMargin: Bool {
        addMarginEnabled ?? true
    }

    public var canRemoveMargin: Bool {
        removeMarginEnabled ?? true
    }

    public var canEditAutoClose: Bool {
        autoCloseEnabled ?? true
    }
}

public extension Optional where Wrapped == PerpsTradingFlags {
    var canOpen: Bool {
        self?.canOpen ?? false
    }

    var canClose: Bool {
        self?.canClose ?? true
    }

    var canCancelOrders: Bool {
        self?.canCancelOrders ?? true
    }

    var canAddMargin: Bool {
        self?.canAddMargin ?? true
    }

    var canRemoveMargin: Bool {
        self?.canRemoveMargin ?? true
    }

    var canEditAutoClose: Bool {
        self?.canEditAutoClose ?? true
    }
}

public struct PerpsTradingSnapshot: Sendable {
    public let flags: PerpsTradingFlags?
    public let orders: PerpsActiveOrders?

    public init(flags: PerpsTradingFlags?, orders: PerpsActiveOrders?) {
        self.flags = flags
        self.orders = orders
    }
}

public struct PerpsMarketExtras: Equatable, Sendable {
    public let limitOrders: [PerpsLimitOrderSummary]
    public let triggerOrders: [PerpsTriggerOrderSummary]
    public let recentActivity: [PerpsHistoryEvent]
    public let flags: PerpsTradingFlags?
    public let autoCloseKnown: Bool

    public init(
        limitOrders: [PerpsLimitOrderSummary] = [],
        triggerOrders: [PerpsTriggerOrderSummary],
        recentActivity: [PerpsHistoryEvent],
        flags: PerpsTradingFlags? = nil,
        autoCloseKnown: Bool = true
    ) {
        self.limitOrders = limitOrders
        self.triggerOrders = triggerOrders
        self.recentActivity = recentActivity
        self.flags = flags
        self.autoCloseKnown = autoCloseKnown
    }
}
