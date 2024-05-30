import Foundation
import TonSwift
import TonAPI
import BigInt

public protocol AccountStakingInfoService {
  func loadAccountStakingInfo(
    address: Address,
    isTestnet: Bool
  ) async throws -> [AccountStakingInfo]
  
  func getAccountStakingInfo(
    address: Address,
    isTestnet: Bool
  ) throws -> [AccountStakingInfo]
}

public final class AccountStakingInfoServiceImplementation: AccountStakingInfoService {
  private let apiProvider: APIProvider
  private var repository: AccountStakingInfoRepository
  
  init(apiProvider: APIProvider, repository: AccountStakingInfoRepository) {
    self.apiProvider = apiProvider
    self.repository = repository
  }
  
  public func loadAccountStakingInfo(
    address: Address,
    isTestnet: Bool
  ) async throws -> [AccountStakingInfo] {
    let info = try await apiProvider.api(isTestnet).getAccountStakingInfo(address: address)
    try repository.saveStakingInfo(info, key: address.makeSaveKey(isTetsnet: isTestnet))
    
    return info
  }
  
  public func getAccountStakingInfo(address: Address, isTestnet: Bool) throws -> [AccountStakingInfo] {
    let key = address.makeSaveKey(isTetsnet: isTestnet)
    return try repository.getStakingInfo(key: key)
  }
}

private extension Address {
  func makeSaveKey(isTetsnet: Bool) -> String {
    FriendlyAddress(address: self, testOnly: isTetsnet, bounceable: true).toShort()
  }
}
