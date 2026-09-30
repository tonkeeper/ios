import Foundation

public struct PerpsPositionSummary: Equatable, Sendable {
    public let positionId: String
    public let marketId: Int64
    public let symbol: String
    public let side: PerpsTradeSide
    public let baseSize: Double
    public let notionalUsd: Double
    public let marginUsd: Double
    public let equityUsd: Double
    public let leverage: Double?
    public let roiPercent: Double?
    public let entryPrice: Double
    public let liquidationPrice: Double
    public let unrealizedPnlUsd: Double
    public let realizedPnlUsd: Double
    public let fundingPaidUsd: Double?
    public let liquidationDistancePercent: Double?

    public var effectiveLeverage: Double? {
        if let leverage, leverage > 0 { return leverage }
        guard marginUsd > 0, notionalUsd > 0 else { return nil }
        return notionalUsd / marginUsd
    }

    public func triggerProjection(triggerPrice: Double, baseAmount: Double) -> (pnlUsd: Double, roePercent: Double?) {
        let direction = side == .long ? 1.0 : -1.0
        let pnl = direction * (triggerPrice - entryPrice) * baseAmount
        let roe = marginUsd > 0 ? pnl / marginUsd * 100 : nil
        return (pnl, roe)
    }

    public func reducePercent(baseAmount: Double) -> Int {
        guard baseSize > 0 else { return 0 }
        return min(100, max(0, Int((baseAmount / baseSize * 100).rounded())))
    }

    public init(
        positionId: String,
        marketId: Int64,
        symbol: String,
        side: PerpsTradeSide,
        baseSize: Double,
        notionalUsd: Double,
        marginUsd: Double,
        equityUsd: Double,
        leverage: Double?,
        roiPercent: Double?,
        entryPrice: Double,
        liquidationPrice: Double,
        unrealizedPnlUsd: Double,
        realizedPnlUsd: Double,
        fundingPaidUsd: Double?,
        liquidationDistancePercent: Double? = nil
    ) {
        self.positionId = positionId
        self.marketId = marketId
        self.symbol = symbol
        self.side = side
        self.baseSize = baseSize
        self.notionalUsd = notionalUsd
        self.marginUsd = marginUsd
        self.equityUsd = equityUsd
        self.leverage = leverage
        self.roiPercent = roiPercent
        self.entryPrice = entryPrice
        self.liquidationPrice = liquidationPrice
        self.unrealizedPnlUsd = unrealizedPnlUsd
        self.realizedPnlUsd = realizedPnlUsd
        self.fundingPaidUsd = fundingPaidUsd
        self.liquidationDistancePercent = liquidationDistancePercent
    }
}
