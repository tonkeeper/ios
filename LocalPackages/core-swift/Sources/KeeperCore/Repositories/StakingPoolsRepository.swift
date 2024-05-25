import Foundation
import TonAPI
import TonSwift
import CoreComponents

protocol StakingPoolsRepository {
  func savePools(_ pools: [StakingPool], key: String) throws
  func getPools(key: String) throws -> [StakingPool]
  func delete(key: String) throws
}

final class StakingPoolsRepositoryImplementation: StakingPoolsRepository {
  private let fileSystemVault: FileSystemVault<[StakingPool], String>
  
  init(fileSystemVault: FileSystemVault<[StakingPool], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func savePools(_ pools: [StakingPool], key: String) throws {
    try fileSystemVault.saveItem(pools, key: key)
  }
  
  func getPools(key: String) throws -> [StakingPool] {
    try fileSystemVault.loadItem(key: key)
  }
  
  func delete(key: String) throws {
    try fileSystemVault.deleteItem(key: key)
  }
}
