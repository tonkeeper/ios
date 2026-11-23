import KeeperCore
import SwiftUI
import TKLocalize
import WidgetKit
import WidgetUI

/// Day-to-day prices of the favorites, or of the wallet's largest assets for someone with none.
/// A row opens its asset's page; the rest of the widget opens the Trade tab, where the favorites are.
@available(iOS 17.0, *)
struct WatchlistWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WalletWidgetLink.Widget.watchlist.kind,
            provider: WatchlistWidgetTimelineProvider()
        ) { entry in
            WatchlistWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(TKLocales.Widget.Watchlist.title)
        .description(TKLocales.Widget.Watchlist.description)
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct WatchlistWidgetEntry: TimelineEntry {
    let date: Date
    /// `nil` once the app has no wallet: the assets' pages need one.
    let state: TokenListWidgetState?
}

extension WatchlistWidgetEntry {
    static let placeholder = WatchlistWidgetEntry(
        date: Date(),
        state: TokenListWidgetState(
            rows: [
                row(.ton, name: TonInfo.name, price: "$1.22", change: "+1.82%"),
                row(PriceWidgetSnapshot.Asset(id: "btc/mainnet/coin", symbol: "BTC"), name: "Bitcoin", price: "$80,076", change: "−0.64%"),
                row(PriceWidgetSnapshot.Asset(id: "eth/mainnet/coin", symbol: "ETH"), name: "Ethereum", price: "$2,316.39", change: "+0.95%"),
                row(PriceWidgetSnapshot.Asset(id: "bnb/mainnet/coin", symbol: "BNB"), name: "BNB", price: "$741.68", change: "+0.54%"),
                row(PriceWidgetSnapshot.Asset(id: "trx/mainnet/coin", symbol: "TRX"), name: "TRON", price: "$0.29", change: "+0.21%"),
            ],
            period: TKLocales.Widget.Period.day,
            updatedAt: Date()
        )
    )

    private static func row(_ asset: PriceWidgetSnapshot.Asset, name: String, price: String, change: String) -> TokenListWidgetState.Row {
        let isDown = change.hasPrefix("−")
        return TokenListWidgetState.Row(
            id: asset.id,
            symbol: asset.symbol,
            name: name,
            icon: nil,
            price: price,
            change: WidgetChange(text: change, isDown: isDown),
            chart: isDown ? [3, 2.5, 2.8, 2, 1.6, 1.8, 1] : [1, 1.6, 1.4, 2, 2.6, 2.3, 3],
            url: nil
        )
    }
}

@available(iOS 17.0, *)
private struct WatchlistWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchlistWidgetEntry

    var body: some View {
        Group {
            if let state = entry.state {
                TokenListWidgetView(state: state, family: family)
            } else {
                WidgetMessageView(text: TKLocales.Widget.noWallet, family: family)
            }
        }
        // A tap before any wallet exists is replayed once one is added, so the message only opens the app.
        .widgetURL(entry.state == nil ? nil : WatchlistWidgetTimelineProvider.url(family: family, assetId: nil))
        .keeperWidgetBackground()
    }
}

@available(iOS 17.0, *)
struct WatchlistWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchlistWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchlistWidgetEntry) -> Void) {
        Task {
            let entry = await entry(family: context.family)
            let hasPrices = entry.state?.rows.contains { $0.price != nil } ?? false
            completion(context.isPreview && !hasPrices ? .placeholder : entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchlistWidgetEntry>) -> Void) {
        Task {
            let entry = await entry(family: context.family)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
        }
    }

    /// Prices and their change come from the catalog, the sparklines from each asset's chart; a chart
    /// that cannot be loaded leaves its row without one.
    private func entry(family: WidgetFamily) async -> WatchlistWidgetEntry {
        guard !WalletWidgetSnapshot.hasNoWallets else {
            return WatchlistWidgetEntry(date: Date(), state: nil)
        }
        let assets = Array(PriceWidgetSnapshot.load().watchlist.prefix(TokenListWidgetState.rows(in: family)))
        let loader = PriceWidgetLoader()
        async let loadedItems = loader.marketItems(assets.map(\.id))
        async let loadedCharts = loader.charts(assetIDs: assets.map(\.id), period: .day)
        let items = await loadedItems
        let charts = await loadedCharts
        let icons = await PriceWidgetLoader.icons(assets.compactMap { items?[$0.id]?.imageURL })
        return WatchlistWidgetEntry(
            date: Date(),
            state: TokenListWidgetState(
                rows: assets.map { asset in
                    let item = items?[asset.id]
                    return TokenListWidgetState.Row(
                        id: asset.id,
                        symbol: item?.symbol ?? asset.symbol,
                        name: item?.name,
                        icon: item?.imageURL.flatMap { icons[$0] },
                        price: item?.price.map(loader.formatPrice),
                        change: item?.change24hPercent.map(loader.formatChange),
                        chart: charts[asset.id]?.prices ?? [],
                        url: Self.url(family: family, assetId: asset.id)
                    )
                },
                period: TKLocales.Widget.Period.day,
                updatedAt: items == nil ? nil : Date()
            )
        )
    }

    static func url(family: WidgetFamily, assetId: String?) -> URL? {
        WalletWidgetLink.Family(family).flatMap {
            WalletWidgetLink(widget: .watchlist, family: $0, action: .open, walletId: nil, assetId: assetId).url
        }
    }
}
