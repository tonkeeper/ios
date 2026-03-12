
import Foundation
import TonAPI
import TonSwift

public protocol WalletService {
    func loadWallet(network: Network, address: Address) async throws -> WalletInfo
}

public final class WalletServiceImplementation: WalletService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    public func loadWallet(network: Network, address: Address) async throws -> WalletInfo {
        return try await apiProvider.api(network).getWalletInfo(address: address)
    }
}
