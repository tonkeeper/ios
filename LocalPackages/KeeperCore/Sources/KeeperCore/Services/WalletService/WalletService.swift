
import Foundation
import TonAPI
import TonSwift

public protocol WalletService {
    func loadWallet(network: Network, address: Address) async throws -> WalletInfo
}

final class WalletServiceImplementation: WalletService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func loadWallet(network: Network, address: Address) async throws -> WalletInfo {
        return try await apiProvider.api(network).getWalletInfo(address: address)
    }
}
