import Foundation

/// Names the other side of a transfer: another of the person's own wallets by its name, anyone else by
/// a shortened address. A state carries the full address, the app keeps the person's wallets in the app
/// group, and the widget names the counterparty at render time, so a pushed state reads the same as a
/// local one. Compiled into the widget extension too.
struct TransactionLiveActivityCounterparties: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let id: String
        let isTestnet: Bool
        let name: String
        /// Every spelling of the wallet's addresses, compared as `key(_:)` makes them.
        let addresses: Set<String>
    }

    var entries: [Entry] = []

    /// The shown wallet already names the activity, so a transfer to itself has no counterparty.
    func label(for address: String, shownWalletId: String) -> String? {
        let key = Self.key(address)
        guard let shown = entries.first(where: { $0.id == shownWalletId }) else { return Self.shortened(address) }
        guard !shown.addresses.contains(key) else { return nil }
        let own = entries.first { entry in
            entry.id != shown.id && entry.isTestnet == shown.isTestnet && entry.addresses.contains(key)
        }
        return own?.name ?? Self.shortened(address)
    }

    /// Raw TON and EVM addresses ignore case; any other spelling compares as written.
    static func key(_ address: String) -> String {
        address.hasPrefix("0x") || address.contains(":") ? address.lowercased() : address
    }

    static func shortened(_ address: String) -> String {
        let hexPrefix = address.lowercased().hasPrefix("0x") ? String(address.prefix(2)) : ""
        let body = address.dropFirst(hexPrefix.count)
        guard body.count > 8 else { return address }
        return "\(hexPrefix)\(body.prefix(4))...\(body.suffix(4))"
    }
}

extension TransactionLiveActivityCounterparties {
    private static let storageKey = "transactionLiveActivity.counterparties"

    private static var defaults: UserDefaults? {
        (Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String)
            .flatMap(UserDefaults.init(suiteName:))
    }

    static func load() -> Self {
        guard let data = defaults?.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Self.self, from: data)
        else { return Self() }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.storageKey)
    }
}
