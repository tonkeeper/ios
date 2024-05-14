import Foundation
import TonAPI
import TonSwift

protocol BlockchainService {
  func getWalletAddress(jettonMaster: String, owner: String, isTestnet: Bool) async throws -> Address
}

final class BlockchainServiceImplementation: BlockchainService {
  private let apiProvider: APIProvider
    
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }
  
  func getWalletAddress(jettonMaster: String, owner: String, isTestnet: Bool) async throws -> Address {
    try await apiProvider.api(isTestnet).getWalletAddress(jettonMaster: jettonMaster, owner: owner)
  }
}
