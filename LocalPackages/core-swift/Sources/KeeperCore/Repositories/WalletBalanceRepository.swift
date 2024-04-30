import Foundation
import TonSwift
import CoreComponents

protocol WalletBalanceRepository {
  func getWalletBalance(address: Address) throws -> WalletBalance
  func saveWalletBalance(_ walletBalance: WalletBalance, for address: Address) throws
}

struct WalletBalanceRepositoryImplementation: WalletBalanceRepository {
  let fileSystemVault: FileSystemVault<WalletBalance, Address>
  
  init(fileSystemVault: FileSystemVault<WalletBalance, Address>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getWalletBalance(address: TonSwift.Address) throws -> WalletBalance {
    try fileSystemVault.loadItem(key: address)
  }
  
  func saveWalletBalance(_ walletBalance: WalletBalance,
                         for address: TonSwift.Address) throws{
    try fileSystemVault.saveItem(walletBalance, key: address)
  }
}

extension Address: CustomStringConvertible {
  public var description: String {
    toRaw()
  }
}
