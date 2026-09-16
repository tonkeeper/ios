import Foundation
import TKTradingAPI

public struct TradingMarketItem: Equatable, Identifiable, Sendable {
    public var id: String
    public var symbol: String
    public var name: String
    public var category: TradingAssetCategory
    public var imageURL: URL?
    public var price: Decimal?
    public var change24hPercent: Decimal?
    public var verification: TradingVerification

    public var isUnverified: Bool {
        verification.isUnverified
    }

    public var isTrusted: Bool {
        verification.isTrusted
    }
}

extension TradingMarketItem {
    init(item: Components.Schemas.MarketItem) {
        self.init(
            id: item.asset.id,
            symbol: item.asset.symbol,
            name: item.asset.name,
            category: item.asset.asset_type.asCategory,
            imageURL: URL(string: item.asset.image_url),
            price: item.metrics.price.decimalValue,
            change24hPercent: item.metrics.change_24h_percent.decimalValue,
            verification: TradingVerification(api: item.asset.verification)
        )
    }
}

private extension String {
    var decimalValue: Decimal? {
        Decimal(string: self, locale: Locale(identifier: "en_US_POSIX"))
    }
}

extension Components.Schemas.AssetType {
    var asCategory: TradingAssetCategory {
        switch self {
        case .asset, .commodities, .perpetuals:
            .tokens
        case .stocks:
            .stocks
        case .etfs:
            .etfs
        }
    }
}
