import Foundation
import TonAPI
import TonSwift

public protocol StakingPoolsService {
  func loadAvailablePools(
    address: Address,
    isTestnet: Bool,
    includeUnverified: Bool
  ) async throws -> [StakingPool]
  
  func getPools(
    address: Address,
    isTestnet: Bool
  ) throws -> [StakingPool]
}

final class StakingPoolsServiceImplementation: StakingPoolsService {
  private let apiProvider: APIProvider
  private var repository: StakingPoolsRepository
  
  init(apiProvider: APIProvider, repository: StakingPoolsRepository) {
    self.apiProvider = apiProvider
    self.repository = repository
  }
  
  public func loadAvailablePools(address: Address, isTestnet: Bool, includeUnverified: Bool) async throws -> [StakingPool] {
    let pools = try await apiProvider.api(isTestnet).getStakingPools(
      address: address,
      includeUnverified: includeUnverified
    )
    
    try repository.savePools(pools, key: address.makeSaveKey(isTetsnet: isTestnet))
    
    return pools
  }
  
  public func getPools(address: Address, isTestnet: Bool) throws -> [StakingPool] {
    let key = address.makeSaveKey(isTetsnet: isTestnet)
    
    return try repository.getPools(key: key)
  }
}

private extension Address {
  func makeSaveKey(isTetsnet: Bool) -> String {
    FriendlyAddress(address: self, testOnly: isTetsnet, bounceable: true).toShort()
  }
}
