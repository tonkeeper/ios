import ChainKit
import Foundation

public struct PerpsPositionSummary: Equatable, Sendable {
    public let marketId: Int64
    public let symbol: String
    public let side: PerpsTradeSide
    public let baseSize: Double
    public let notionalUsd: Double
    public let marginUsd: Double
    public let entryPrice: Double
    public let liquidationPrice: Double
    public let unrealizedPnlUsd: Double
    public let realizedPnlUsd: Double
    public let fundingPaidUsd: Double?

    public var leverage: Double? {
        guard marginUsd > 0 else { return nil }
        return (notionalUsd / marginUsd).rounded()
    }

    public var unrealizedPnlPercent: Double? {
        guard marginUsd > 0 else { return nil }
        return unrealizedPnlUsd / marginUsd * 100
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
        marketId: Int64,
        symbol: String,
        side: PerpsTradeSide,
        baseSize: Double,
        notionalUsd: Double,
        marginUsd: Double,
        entryPrice: Double,
        liquidationPrice: Double,
        unrealizedPnlUsd: Double,
        realizedPnlUsd: Double,
        fundingPaidUsd: Double?
    ) {
        self.marketId = marketId
        self.symbol = symbol
        self.side = side
        self.baseSize = baseSize
        self.notionalUsd = notionalUsd
        self.marginUsd = marginUsd
        self.entryPrice = entryPrice
        self.liquidationPrice = liquidationPrice
        self.unrealizedPnlUsd = unrealizedPnlUsd
        self.realizedPnlUsd = realizedPnlUsd
        self.fundingPaidUsd = fundingPaidUsd
    }
}

extension PerpsPositionSummary {
    init?(position: PerpsPosition) {
        let baseSize = abs(PerpsMarketMath.double(position.size))
        guard baseSize > 0 else { return nil }
        self.init(
            marketId: position.marketId,
            symbol: position.symbol,
            side: PerpsTradeSideMapper.fromChainKit(position.side),
            baseSize: baseSize,
            notionalUsd: abs(PerpsMarketMath.double(position.positionValue)),
            marginUsd: PerpsMarketMath.double(position.allocatedMargin),
            entryPrice: PerpsMarketMath.double(position.avgEntryPrice),
            liquidationPrice: PerpsMarketMath.double(position.liquidationPrice),
            unrealizedPnlUsd: PerpsMarketMath.double(position.unrealizedPnl),
            realizedPnlUsd: PerpsMarketMath.double(position.realizedPnl),
            fundingPaidUsd: position.fundingPaid.flatMap { PerpsMarketMath.optionalDouble($0) }
        )
    }
}
