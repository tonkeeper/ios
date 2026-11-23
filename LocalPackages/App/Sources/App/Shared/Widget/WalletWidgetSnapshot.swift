import Foundation

/// What the wallet widgets show, written by the app to the App Group: the widget holds no wallet data
/// and makes no requests, so it shows the balances the app last had.
struct WalletWidgetSnapshot: Codable, Equatable {
    struct Wallet: Codable, Equatable, Identifiable {
        /// The wallet identity's identifier: SiriKit configurations saved before App Intents name wallets by it.
        let id: String
        let name: String
        let emoji: String?
        let icon: String?
        /// Formatted in the app's currency; `nil` while it is unknown or while amounts are hidden.
        let total: String?
        /// The total abbreviated for the smallest widgets, like `$8.2K`.
        let totalCompact: String?
        /// The 24-hour change of the wallet's tokens at their prices: Perps and Earn are not in it.
        let change: Change?
        /// The largest assets in fiat, as many as the medium widget lists.
        let topAssets: [Asset]
        let updatedAt: Date?
        /// The quick actions the wallet screen enables: a watch-only wallet cannot send or swap.
        let actions: Set<WalletWidgetLink.Action>
    }

    struct Change: Codable, Equatable {
        let text: String
        let isDown: Bool
    }

    struct Asset: Codable, Equatable {
        let id: String
        let symbol: String
        /// `nil` while amounts are hidden.
        let amount: String?
        let iconURL: URL?
    }

    var wallets: [Wallet]
    var activeWalletId: String?
    var hidesAmounts: Bool
    /// The wallet screen calls its deposit button Buy while the ramp is on, and Add Funds otherwise.
    var isRampEnabled: Bool
    /// The totals' one, so the widget sets their fraction in a smaller font.
    var decimalSeparator: String

    static let empty = WalletWidgetSnapshot(wallets: [], activeWalletId: nil, hidesAmounts: false, isRampEnabled: false, decimalSeparator: ".")

    /// The configured wallet, or the active one for a widget left to follow it or whose wallet was deleted.
    func wallet(id: String?) -> Wallet? {
        wallets.first { $0.id == id } ?? wallets.first { $0.id == activeWalletId } ?? wallets.first
    }
}

extension WalletWidgetSnapshot {
    private static let storageKey = "walletWidget.snapshot"

    static var defaults: UserDefaults? {
        (Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String)
            .flatMap(UserDefaults.init(suiteName:))
    }

    /// `nil` until the app has written one, as after an update the app has not been opened since.
    static func load() -> Self? {
        guard let data = defaults?.data(forKey: storageKey) else { return nil }
        return (try? JSONDecoder().decode(Self.self, from: data)) ?? .empty
    }

    /// The app has written that it has no wallets. Data that does not decode, as after an update that
    /// changed the format, is not an empty list.
    static var hasNoWallets: Bool {
        guard let data = defaults?.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data)
        else { return false }
        return snapshot.wallets.isEmpty
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.storageKey)
    }
}
