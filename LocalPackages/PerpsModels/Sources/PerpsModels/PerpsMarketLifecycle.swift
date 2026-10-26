public enum PerpsMarketLifecycle: Equatable {
    case flat
    case opening(PerpsOpeningDescriptor)
    case open(PerpsPositionSummary)
    case closing(PerpsPositionSummary)
    case adjusting(PerpsPositionSummary, PerpsSizeChangeDirection)
    case adjustingMargin(PerpsPositionSummary, PerpsMarginChangeDirection, amountUsd: Double)
}

public struct PerpsOpeningDescriptor: Equatable, Sendable {
    public let marketId: Int64
    public let symbol: String
    public let side: PerpsTradeSide
    public let marginUsd: Double
    public let leverage: Double
    public let isLimit: Bool

    public init(marketId: Int64, symbol: String, side: PerpsTradeSide, marginUsd: Double, leverage: Double, isLimit: Bool) {
        self.marketId = marketId
        self.symbol = symbol
        self.side = side
        self.marginUsd = marginUsd
        self.leverage = leverage
        self.isLimit = isLimit
    }
}
