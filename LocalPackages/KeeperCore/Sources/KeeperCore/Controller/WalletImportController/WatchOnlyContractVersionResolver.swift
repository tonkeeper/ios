import Foundation
import TKLogging
import TonSwift

/// Recognises the contract behind a watch-only address, which carries no version of its own.
struct WatchOnlyContractVersionResolver {
    static let defaultTimeLimit: TimeInterval = 5

    let accountLoader: TelegramWalletAccountLoader
    var timeLimit: TimeInterval = WatchOnlyContractVersionResolver.defaultTimeLimit

    /// A failed, slow or cancelled lookup leaves the version unknown instead of holding up the import.
    func contractVersion(address: Address, network: Network) async -> WalletContractVersion? {
        let interfaces = await withTimeLimit(timeLimit) { [accountLoader] in
            do {
                return try await accountLoader.account(address: address, network: network).interfaces
            } catch {
                Log.w("Watch-only contract version lookup failed: \(error)")
                return []
            }
        }
        return Self.contractVersion(interfaces: interfaces ?? [])
    }

    static func contractVersion(interfaces: [String]) -> WalletContractVersion? {
        let versions: [(interface: String, version: WalletContractVersion)] = [
            (TelegramWalletFinder.walletTgInterface, .walletTg),
            ("wallet_v5_beta", .v5Beta),
            ("wallet_v5", .v5R1),
            ("wallet_v5r1", .v5R1),
            ("wallet_v4r2", .v4R2),
            ("wallet_v3r2", .v3R2),
            ("wallet_v3r1", .v3R1),
            ("wallet_v4r1", .v4R1),
        ]
        return versions.first { interfaces.contains($0.interface) }?.version
    }
}
