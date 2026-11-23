import Foundation
import KeeperCoreComponents
import TonSwift

/// A transfer push sent to a device with more than one subscribed wallet carries `body_template`: the
/// server's body with `{wallet_name}` left for the name the wallet has on this device.
public struct PushBodyTemplate {
    private let template: String
    private let walletId: String?
    private let address: String?

    public init?(userInfo: [AnyHashable: Any]) {
        guard let template = userInfo["body_template"] as? String, !template.isBlank else { return nil }
        self.template = template
        walletId = userInfo["wallet_id"] as? String
        address = userInfo["address"] as? String
    }

    /// Reads the wallets from the KeeperInfo the app keeps in the App Group container. `nil` keeps the
    /// server's body; an app with a single wallet always keeps it.
    public func body(sharedCacheURL: URL) -> String? {
        let repository = FileSystemVault<KeeperInfo, String>(fileManager: .default, directory: sharedCacheURL)
        guard let wallets = try? repository.getKeeperInfo().wallets else { return nil }
        return body(wallets: wallets)
    }

    func body(wallets: [Wallet]) -> String? {
        guard wallets.count > 1, let name = wallet(in: wallets)?.label, !name.isBlank else { return nil }
        return template.replacingOccurrences(of: "{wallet_name}", with: name)
    }

    private func wallet(in wallets: [Wallet]) -> Wallet? {
        if let walletId, let wallet = wallets.first(where: { $0.multichainWalletId == walletId }) {
            return wallet
        }
        guard let address = address.flatMap({ try? Address.parse($0) }) else { return nil }
        // A testnet wallet can share its raw address with a mainnet one; pushes come from mainnet.
        return wallets.first { $0.network == .mainnet && (try? $0.address) == address }
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
