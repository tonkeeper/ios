import Foundation

public struct PerpsMarketSummary: Equatable, Sendable {
    public let marketId: Int64
    public let symbol: String
    public let name: String
    public let iconURL: URL?
    public let maxLeverage: Int
    public let price: Double
    public let priceChangePercent: Double
    public let volume24h: Double

    public var hasPrice: Bool {
        price > 0
    }

    public init(
        marketId: Int64,
        symbol: String,
        name: String,
        iconURL: URL?,
        maxLeverage: Int,
        price: Double,
        priceChangePercent: Double,
        volume24h: Double
    ) {
        self.marketId = marketId
        self.symbol = symbol
        self.name = name
        self.iconURL = iconURL
        self.maxLeverage = maxLeverage
        self.price = price
        self.priceChangePercent = priceChangePercent
        self.volume24h = volume24h
    }

    public func overlayingLivePrice(_ livePrice: Double?) -> PerpsMarketSummary {
        guard let livePrice, livePrice > 0, livePrice != price else { return self }
        return PerpsMarketSummary(
            marketId: marketId,
            symbol: symbol,
            name: name,
            iconURL: iconURL,
            maxLeverage: maxLeverage,
            price: livePrice,
            priceChangePercent: PerpsMarketMath.changePercent(
                livePrice: livePrice,
                snapshotPrice: price,
                snapshotChangePercent: priceChangePercent
            ),
            volume24h: volume24h
        )
    }
}

public struct PerpsMarketsPage: Equatable, Sendable {
    public let items: [PerpsMarketSummary]
    public let nextCursor: String?

    public init(items: [PerpsMarketSummary], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
