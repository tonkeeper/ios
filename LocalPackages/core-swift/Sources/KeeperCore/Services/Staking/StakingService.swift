import Foundation
import TonSwift

public protocol StakingService {
  func loadStakingPools(wallet: Wallet) async throws -> [StackingPoolInfo]
  func loadStakingBalance(wallet: Wallet) async throws -> [AccountStackingInfo]
}

final class StakingServiceImplementation: StakingService {
  
  private let apiProvider: APIProvider
  
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }
  
  func loadStakingPools(wallet: Wallet) async throws -> [StackingPoolInfo] {
    return try await apiProvider.api(wallet.isTestnet).getPools(address: wallet.address)
  }
  
  func loadStakingBalance(wallet: Wallet) async throws -> [AccountStackingInfo] {
    return try await apiProvider.api(wallet.isTestnet).getNominators(address: wallet.address)
  }
}
