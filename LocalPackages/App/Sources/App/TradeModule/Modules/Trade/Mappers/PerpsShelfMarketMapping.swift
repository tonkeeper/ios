import Foundation
import KeeperCore
import Perps
import PerpsModels

enum PerpsShelfMarketMapping {
    private static let format = PerpsFormatting.live

    static let displayLimit = 8

    static func items(
        from markets: [PerpsMarketSummary],
        itemsMapper: TradeItemsMapper
    ) -> [PerpsShelfMarketViewData] {
        markets.prefix(displayLimit).map { item(from: $0, itemsMapper: itemsMapper) }
    }

    static func item(
        from market: PerpsMarketSummary,
        itemsMapper: TradeItemsMapper
    ) -> PerpsShelfMarketViewData {
        let change = Decimal(market.priceChangePercent)
        return PerpsShelfMarketViewData(
            id: market.marketId,
            symbol: market.symbol,
            iconURL: market.iconURL,
            leverage: format.leverageBadge(Double(market.maxLeverage)),
            changeText: itemsMapper.formatChange(change),
            changeColor: itemsMapper.changeColor(for: change)
        )
    }
}
