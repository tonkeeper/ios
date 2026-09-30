import Foundation
import KeeperCore
import TKLocalize

struct PerpsMarketRowItem: Identifiable, Equatable {
    let id: Int64
    let symbol: String
    let iconURL: URL?
    let leverageText: String?
    let volumeText: String
    let priceText: String
    let changeText: String
    let isChangePositive: Bool
}

enum PerpsMarketRowMapping {
    static func item(from market: PerpsMarketSummary) -> PerpsMarketRowItem {
        PerpsMarketRowItem(
            id: market.marketId,
            symbol: market.symbol,
            iconURL: market.iconURL,
            leverageText: market.maxLeverage > 0 ? PerpsFormatting.leverageBadge(Double(market.maxLeverage)) : nil,
            volumeText: "\(PerpsFormatting.usd(market.volume24h)) \(TKLocales.Perps.volumeShort)",
            priceText: PerpsFormatting.usd(market.price),
            changeText: PerpsFormatting.signedPercent(market.priceChangePercent),
            isChangePositive: market.priceChangePercent >= 0
        )
    }
}
