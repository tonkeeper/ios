import Foundation
import TonAPI
import TonSwift
import CoreComponents

protocol AccountStakingInfoRepository {
  func saveStakingInfo(_ info: [AccountStakingInfo], key: String) throws
  func getStakingInfo(key: String) throws -> [AccountStakingInfo]
}

final class AccountStakingInfoRepositoryImplementation: AccountStakingInfoRepository {
  private let fileSystemVault: FileSystemVault<[AccountStakingInfo], String>
  
  init(fileSystemVault: FileSystemVault<[AccountStakingInfo], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveStakingInfo(_ info: [AccountStakingInfo], key: String) throws {
    try fileSystemVault.saveItem(info, key: key)
  }
  
  func getStakingInfo(key: String) throws -> [AccountStakingInfo] {
    try fileSystemVault.loadItem(key: key)
  }
}
