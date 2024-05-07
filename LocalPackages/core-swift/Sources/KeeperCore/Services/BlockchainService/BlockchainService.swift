import Foundation
import TonAPI
import TonSwift

protocol BlockchainService {
  func getWalletAddress(jettonMaster: String, owner: String) async throws -> Address
}

final class BlockchainServiceImplementation: BlockchainService {
    private let api: API
    
    init(api: API) {
        self.api = api
    }
    
  func getWalletAddress(jettonMaster: String, owner: String) async throws -> Address {
    try await api.getWalletAddress(jettonMaster: jettonMaster, owner: owner)
    }
}
