import AppIntents
import WidgetKit

/// Keeps the wallet chosen in a widget configured before App Intents: the system maps the SiriKit
/// intent's `wallet` parameter onto this one by name.
@available(iOS 17.0, *)
struct BalanceWidgetConfigurationIntent: WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "BalanceWidgetIntent"
    static let title = LocalizedStringResource("Wallet Balance", table: "BalanceWidget")

    @Parameter(title: LocalizedStringResource("Wallet", table: "BalanceWidget"))
    var wallet: WalletWidgetEntity?
}

@available(iOS 17.0, *)
struct WalletWidgetEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Wallet", table: "BalanceWidget"))
    static let defaultQuery = WalletWidgetEntityQuery()

    let id: String
    let name: String
    let emoji: String?

    var displayRepresentation: DisplayRepresentation {
        if id == Self.active.id {
            return DisplayRepresentation(title: LocalizedStringResource("Active Wallet", table: "BalanceWidget"))
        }
        return DisplayRepresentation(title: "\(emoji.map { "\($0) " } ?? "")\(name)")
    }

    /// The configured wallet's id, or `nil` for a widget that follows the active one.
    var walletId: String? {
        id == Self.active.id ? nil : id
    }
}

@available(iOS 17.0, *)
extension WalletWidgetEntity {
    /// What a new widget starts on. The system asks for the default once, when the app is installed or
    /// updated, so a concrete wallet would be the one active then.
    static let active = WalletWidgetEntity(id: "active", name: "", emoji: nil)

    init(_ wallet: WalletWidgetSnapshot.Wallet) {
        self.init(id: wallet.id, name: wallet.name, emoji: wallet.emoji)
    }
}

@available(iOS 17.0, *)
struct WalletWidgetEntityQuery: EntityQuery {
    /// A migrated configuration can name a wallet before the app has written the snapshot: the id is
    /// kept, and the widget shows the active wallet until the snapshot catches up.
    func entities(for identifiers: [String]) async throws -> [WalletWidgetEntity] {
        let wallets = WalletWidgetSnapshot.load()?.wallets ?? []
        return identifiers.map { id in
            if id == WalletWidgetEntity.active.id { return .active }
            return wallets.first { $0.id == id }.map(WalletWidgetEntity.init) ?? WalletWidgetEntity(id: id, name: id, emoji: nil)
        }
    }

    func suggestedEntities() async throws -> [WalletWidgetEntity] {
        [.active] + (WalletWidgetSnapshot.load()?.wallets ?? []).map(WalletWidgetEntity.init)
    }

    func defaultResult() async -> WalletWidgetEntity? {
        .active
    }
}
