import Foundation
import PerpsModels
import TKLocalize

public enum PerpsMarketRowMapping {
    public static func item(from market: PerpsMarketSummary, format: PerpsFormatting) -> PerpsMarketRowItem {
        PerpsMarketRowItem(
            id: market.marketId,
            symbol: market.symbol,
            iconURL: market.iconURL,
            leverageText: market.maxLeverage > 0 ? format.leverageBadge(Double(market.maxLeverage)) : nil,
            volumeText: TKLocales.Perps.volumePattern(format.usdShort(market.volume24h)),
            priceText: format.price(market.price),
            changeText: format.priceChange(market.priceChangePercent),
            isChangePositive: market.priceChangePercent == 0 ? nil : market.priceChangePercent > 0
        )
    }
}
