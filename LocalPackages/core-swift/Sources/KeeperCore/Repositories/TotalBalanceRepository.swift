import Foundation
import TonSwift
import CoreComponents

protocol TotalBalanceRepository {
  func getTotalBalance(address: Address, currency: Currency) throws -> TotalBalance
  func saveTotalBalance(totalBalance: TotalBalance, address: Address, currency: Currency) throws
}

struct TotalBalanceRepositoryImplementation: TotalBalanceRepository {
  let fileSystemVault: FileSystemVault<TotalBalance, String>
  
  init(fileSystemVault: FileSystemVault<TotalBalance, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getTotalBalance(address: Address, currency: Currency) throws -> TotalBalance {
    let key = "\(address.toRaw())_\(currency.code)"
    return try fileSystemVault.loadItem(key: key)
  }
  
  func saveTotalBalance(totalBalance: TotalBalance, address: Address, currency: Currency) throws {
    let key = "\(address.toRaw())_\(currency.code)"
    try fileSystemVault.saveItem(totalBalance, key: key)
  }
}
