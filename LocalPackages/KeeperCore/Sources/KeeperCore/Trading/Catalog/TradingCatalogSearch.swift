import Foundation
import TKTradingAPI

public enum TradingCatalogRow: Equatable, Sendable {
    case spot(TradingCatalogSpot)
    case perp(PerpsMarketSummary)
}

public struct TradingCatalogSpot: Equatable, Sendable {
    public let id: String
    public let symbol: String
    public let name: String
    public let imageURL: URL?
    public let decimals: Int
    public let verification: TradingVerification
    public let price: String
    public let change24hPercent: String
    public let marketCap: String?

    public init(
        id: String,
        symbol: String,
        name: String,
        imageURL: URL?,
        decimals: Int,
        verification: TradingVerification,
        price: String,
        change24hPercent: String,
        marketCap: String?
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
        self.decimals = decimals
        self.verification = verification
        self.price = price
        self.change24hPercent = change24hPercent
        self.marketCap = marketCap
    }
}

public struct TradingCatalogPage: Equatable, Sendable {
    public let rows: [TradingCatalogRow]
    public let nextCursor: String?

    public init(rows: [TradingCatalogRow], nextCursor: String?) {
        self.rows = rows
        self.nextCursor = nextCursor
    }
}

public protocol TradingCatalogSearching: AnyObject, Sendable {
    func catalogSearch(
        query: String?,
        chain: String?,
        showPerps: Bool,
        sort: MultichainAssetSearchSort,
        cursor: String?,
        pageSize: Int
    ) async throws -> TradingCatalogPage
}

extension TradingCatalogRow {
    init?(item: Components.Schemas.MarketItem) {
        if item.asset.asset_type == .perpetuals || PerpsMarketAssetID.marketId(assetId: item.asset.id) != nil {
            guard let market = PerpsMarketSummary(item: item) else {
                return nil
            }
            self = .perp(market)
            return
        }
        self = .spot(TradingCatalogSpot(item: item))
    }
}

extension TradingCatalogSpot {
    init(item: Components.Schemas.MarketItem) {
        self.init(
            id: item.asset.id,
            symbol: item.asset.symbol,
            name: item.asset.name,
            imageURL: item.asset.image_url.nilIfEmpty.flatMap { URL(string: $0) },
            decimals: item.asset.decimals,
            verification: TradingVerification(api: item.asset.verification),
            price: item.metrics.price,
            change24hPercent: item.metrics.change_24h_percent,
            marketCap: item.metrics.market_cap
        )
    }
}

extension MultichainAssetSearchSort {
    var tradingCatalogSort: (Components.Schemas.AssetsSort, Components.Schemas.AssetsOrder) {
        switch self {
        case .marketCap:
            (.market_cap, .desc)
        case .volume:
            (.volume_24h, .desc)
        case .priceDiffDesc:
            (.price_24h, .desc)
        case .priceDiffAsc:
            (.price_24h, .asc)
        }
    }
}
