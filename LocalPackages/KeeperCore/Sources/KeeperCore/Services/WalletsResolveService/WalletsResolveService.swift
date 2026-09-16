import Foundation
import TonSwift

public protocol WalletsResolveService {
    func resolveWalletsByPubkey(_ wallets: [Wallet])
    func resolveWallets(by pubkey: TonSwift.PublicKey)
}

final class WalletsResolveServiceImplementation: WalletsResolveService {
    private let apiProvider: APIProvider
    private let firebaseUserIdProvider: () -> String?

    init(apiProvider: APIProvider, firebaseUserIdProvider: @escaping () -> String?) {
        self.apiProvider = apiProvider
        self.firebaseUserIdProvider = firebaseUserIdProvider
    }

    func resolveWalletsByPubkey(_ wallets: [Wallet]) {
        let publicKeys = Self.mainnetPublicKeysHexExcludingWatchOnly(from: wallets)
        guard !publicKeys.isEmpty else { return }
        Task {
            try? await getWalletsByPubkeysBulk(publicKeys: publicKeys)
        }
    }

    func resolveWallets(by pubkey: TonSwift.PublicKey) {
        Task {
            try? await getWalletsByPubkeysBulk(publicKeys: [pubkey.hexString])
        }
    }
}

private extension WalletsResolveServiceImplementation {
    @discardableResult
    func getWalletsByPubkeysBulk(publicKeys: [String]) async throws -> [(publicKey: String, wallets: [WalletInfo])] {
        let api = apiProvider.api(.mainnet)
        return try await api.getWalletsByPubkeysBulk(publicKeys: publicKeys, firebaseUserId: firebaseUserIdProvider())
    }

    static func mainnetPublicKeysHexExcludingWatchOnly(from wallets: [Wallet]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for wallet in wallets where wallet.network == .mainnet && wallet.kind != .watchonly {
            guard let pubkey = try? wallet.publicKey else { continue }
            let hex = pubkey.hexString
            if seen.insert(hex).inserted {
                result.append(hex)
            }
        }
        return result
    }
}
