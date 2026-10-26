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
            volumeText: TKLocales.Perps.volumePattern(format.usd(market.volume24h)),
            priceText: format.usd(market.price),
            changeText: format.signedPercent(market.priceChangePercent),
            isChangePositive: market.priceChangePercent >= 0
        )
    }
}
