import Foundation
import TonAPI
import TonSwift

public protocol BlockchainService {
    func getWalletAddress(jettonMaster: String, owner: String, network: Network) async throws -> Address
}

final class BlockchainServiceImplementation: BlockchainService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func getWalletAddress(jettonMaster: String, owner: String, network: Network) async throws -> Address {
        try await apiProvider.api(network).getWalletAddress(jettonMaster: jettonMaster, owner: owner)
    }
}
