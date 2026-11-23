import KeeperCore
import TKAppInfo
import TKFeatureFlags
import TKLocalize
import UIKit
import WidgetUI

/// Loads what the price widgets show from the trading catalog, in the app's currency. Nothing it hands
/// out keeps the KeeperCore graph alive, so a caller keeps the loader until its requests are done.
final class PriceWidgetLoader {
    struct Chart {
        /// Oldest first.
        let prices: [Double]
        /// `false` for the copy cached when the catalog was last reached.
        let isFresh: Bool
    }

    private let keeperCoreAssembly: KeeperCore.Assembly
    private let widgetAssembly: WidgetAssembly

    init() {
        keeperCoreAssembly = KeeperCore.Assembly(
            dependencies: Assembly.Dependencies(
                cacheURL: AppDirectories.documents,
                sharedCacheURL: AppDirectories.sharedCache,
                appInfoProvider: DeviceAppInfoProvider(
                    userDefaults: .standard,
                    storefrontCountryCodeCache: StorefrontCountryCodeCache()
                ),
                featureFlags: DummyFeatureFlags(),
                seedProvider: { "" }
            )
        )
        widgetAssembly = keeperCoreAssembly.widgetAssembly()
    }

    var currency: Currency {
        widgetAssembly.currency
    }

    /// Keyed by asset id; `nil` when the catalog cannot be reached.
    func marketItems(_ assetIDs: [String]) async -> [String: TradingMarketItem]? {
        guard let items = try? await widgetAssembly.marketItems(assetIDs: assetIDs) else { return nil }
        return Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func chart(assetId: String, period: KeeperCore.Period) async -> Chart {
        let controller = widgetAssembly.chartV2Controller(assetId: assetId)
        if let coordinates = try? await controller.loadChartData(period: period, currency: currency), !coordinates.isEmpty {
            return Chart(prices: coordinates.map(\.y), isFresh: true)
        }
        return Chart(prices: controller.getCachedChartData(period: period, currency: currency)?.map(\.y) ?? [], isFresh: false)
    }

    func charts(assetIDs: [String], period: KeeperCore.Period) async -> [String: Chart] {
        await withTaskGroup(of: (String, Chart).self) { group in
            for id in Set(assetIDs) {
                group.addTask { await(id, self.chart(assetId: id, period: period)) }
            }
            return await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
        }
    }

    static func icon(_ url: URL?) async -> UIImage? {
        guard let url, let data = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10)).0 else { return nil }
        return UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 96, height: 96))
    }

    static func icons(_ urls: [URL]) async -> [URL: UIImage] {
        await withTaskGroup(of: (URL, UIImage?).self) { group in
            for url in Set(urls) {
                group.addTask { await(url, icon(url)) }
            }
            return await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
        }
    }

    func formatPrice(_ price: Decimal) -> String {
        formatters.amountFormatter.format(decimal: price, accessory: .fiat(currency), style: .compact)
    }

    func formatChange(_ percent: Decimal) -> WidgetChange {
        .signed(formatters.signedAmountFormatter.format(decimal: percent, style: .percent))
    }

    func formatFiatChange(_ amount: Decimal) -> WidgetChange {
        .signed(formatters.signedAmountFormatter.format(decimal: amount, accessory: .fiat(currency), style: .compact))
    }

    private var formatters: KeeperCore.FormattersAssembly {
        keeperCoreAssembly.rootAssembly().formattersAssembly
    }
}

private extension WidgetChange {
    /// A change that rounds to zero is formatted unsigned, so its colour follows the text, not the raw value.
    static func signed(_ text: String) -> WidgetChange {
        WidgetChange(text: text, isDown: text.contains(String.Symbol.minus))
    }
}
