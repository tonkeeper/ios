import Foundation
import KeeperCore
import WidgetKit
import WidgetUI

@available(iOS 17.0, *)
struct RateWidgetTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RateWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: RateWidgetConfigurationIntent, in context: Context) async -> RateWidgetEntry {
        let entry = await entry(for: configuration)
        return context.isPreview && entry.state?.price == nil ? .placeholder : entry
    }

    func timeline(for configuration: RateWidgetConfigurationIntent, in context: Context) async -> Timeline<RateWidgetEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
    }

    /// The price and its change come from the period's chart, so they match the line drawn. A chart from the cache can
    /// be days old, so then the catalog's price wins, with its 24h change for the day.
    private func entry(for configuration: RateWidgetConfigurationIntent) async -> RateWidgetEntry {
        let asset = configuration.asset?.asset(in: .load()) ?? .ton
        guard !WalletWidgetSnapshot.hasNoWallets else {
            return RateWidgetEntry(date: Date(), assetId: asset.id, state: nil)
        }
        let period = configuration.period
        let loader = PriceWidgetLoader()
        async let items = loader.marketItems([asset.id])
        async let loadedChart = loader.chart(assetId: asset.id, period: period.period)
        let item = await items?[asset.id]
        let chart = await loadedChart
        let icon = await PriceWidgetLoader.icon(item?.imageURL)

        let usesChart = chart.isFresh || item?.price == nil
        let price = usesChart ? chart.prices.last.map { Decimal($0) } : item?.price
        let change = PriceWidgetSnapshot.change(
            prices: usesChart ? chart.prices : [],
            price: price,
            percent24h: period == .day ? item?.change24hPercent : nil
        )
        return RateWidgetEntry(
            date: Date(),
            assetId: asset.id,
            state: TokenWidgetState(
                symbol: item?.symbol ?? asset.symbol,
                icon: icon,
                price: price.map(loader.formatPrice),
                change: change.map { loader.formatChange($0.percent) },
                fiatChange: change.map { loader.formatFiatChange($0.amount) },
                period: period.label,
                updatedAt: chart.isFresh || !usesChart ? Date() : nil,
                chart: chart.prices
            )
        )
    }
}
