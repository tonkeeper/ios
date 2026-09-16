import Foundation
import TKTradingAPI

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

extension PerpsMarketSummary {
    init?(item: Components.Schemas.MarketItem) {
        guard let marketId = PerpsMarketAssetID.marketId(assetId: item.asset.id),
              let symbol = item.asset.symbol.nilIfEmpty
        else {
            return nil
        }
        let changePercent = item.metrics.change_24h_percent.replacingOccurrences(of: "%", with: "")
        self.init(
            marketId: marketId,
            symbol: symbol,
            name: item.asset.name,
            iconURL: item.asset.image_url.nilIfEmpty.flatMap { URL(string: $0) },
            maxLeverage: max(0, item.asset.leverage ?? 0),
            price: PerpsMarketMath.optionalDouble(item.metrics.price) ?? 0,
            priceChangePercent: PerpsMarketMath.optionalDouble(changePercent) ?? 0,
            volume24h: PerpsMarketMath.optionalDouble(item.metrics.volume) ?? 0
        )
    }
}
