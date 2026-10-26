import Foundation
import PerpsModels
import TKTradingAPI

extension PerpsMarketsSort {
    var tradingApiValue: Components.Schemas.AssetsSort {
        switch self {
        case .volume:
            .volume_24h
        case .priceChange:
            .price_24h
        case .openInterest:
            .open_interest_usd
        }
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
