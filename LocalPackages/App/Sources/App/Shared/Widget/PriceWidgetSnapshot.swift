import Foundation
import KeeperCore

/// The assets the price widgets offer, written by the app to the App Group: the favorites and the
/// balances live in the app, while the widgets load prices themselves.
struct PriceWidgetSnapshot: Codable, Equatable {
    struct Asset: Codable, Equatable, Identifiable {
        /// The trading catalog id, as in `tonkeeper://assets/<id>`.
        let id: String
        let symbol: String
    }

    /// In the Trade tab's order: the latest added first.
    var favorites: [Asset]
    /// The active wallet's assets with a balance, the largest in fiat first.
    var walletAssets: [Asset]
    /// The app's currency code. The widgets show prices in it, so a change reloads them.
    var currency: String?

    static let empty = PriceWidgetSnapshot(favorites: [], walletAssets: [], currency: nil)

    /// The favorites, or the wallet's largest assets for someone with none: what a watchlist shows and
    /// the asset a new price widget starts on.
    var watchlist: [Asset] {
        if !favorites.isEmpty { return favorites }
        if !walletAssets.isEmpty { return walletAssets }
        return [.ton]
    }

    /// Every asset a price widget can be set to.
    var choices: [Asset] {
        var seen = Set<String>()
        return (favorites + walletAssets + [.ton]).filter { seen.insert($0.id).inserted }
    }
}

extension PriceWidgetSnapshot {
    /// From the chart's ends, or, without a chart, from the catalog's 24-hour percent: a price that moved
    /// by `p`% to `price` moved by `price·p/(100+p)`.
    static func change(prices: [Double], price: Decimal?, percent24h: Decimal?) -> (percent: Decimal, amount: Decimal)? {
        if prices.count > 1, let first = prices.first, let last = prices.last, first != 0 {
            return (Decimal((last - first) / first * 100), Decimal(last - first))
        }
        guard let price, let percent24h, percent24h > -100 else { return nil }
        return (percent24h, price * percent24h / (100 + percent24h))
    }
}

extension PriceWidgetSnapshot.Asset {
    /// What price widgets placed before App Intents show: they had no asset to choose.
    static let ton = Self(id: AssetId.coin(chain: .ton, network: .mainnet), symbol: TonInfo.symbol)
}

extension PriceWidgetSnapshot {
    private static let storageKey = "priceWidget.snapshot"

    static func load() -> Self {
        guard let data = WalletWidgetSnapshot.defaults?.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Self.self, from: data)
        else { return .empty }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        WalletWidgetSnapshot.defaults?.set(data, forKey: Self.storageKey)
    }
}
