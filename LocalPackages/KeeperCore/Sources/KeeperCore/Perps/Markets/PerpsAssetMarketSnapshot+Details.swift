import Foundation
import PerpsModels

extension PerpsAssetMarketSnapshot {
    init(details: PerpsMarketDetails) {
        let market = details.metadata
        let price = market.displayPrice
        self.init(
            marketId: market.marketId,
            symbol: market.symbol,
            displayName: details.name.nilIfEmpty ?? market.symbol,
            status: market.status,
            maxLeverage: market.maxLeverage,
            priceDecimals: market.priceDecimals,
            sizeDecimals: market.sizeDecimals,
            price: price,
            priceChangePercent: market.priceChangePercent,
            priceChangeAmount: PerpsMarketMath.changeAmount(price: price, changePercent: market.priceChangePercent),
            volume24h: market.volume24h,
            openInterest: market.openInterest,
            fundingRatePercent: market.fundingRatePercent,
            about: details.about,
            openEnabled: market.status.lowercased() == "active",
            iconURL: details.iconURL
        )
    }
}
