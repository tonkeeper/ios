import Foundation
import TonSwift
import CoreComponents

protocol WalletBalanceRepositoryV2 {
  func getBalance(address: FriendlyAddress) throws -> WalletBalance
  func saveWalletBalance(_ walletBalance: WalletBalance, for address: FriendlyAddress) throws
}

struct WalletBalanceRepositoryV2implementation: WalletBalanceRepositoryV2 {
  let fileSystemVault: FileSystemVault<WalletBalance, FriendlyAddress>
  
  init(fileSystemVault: FileSystemVault<WalletBalance, FriendlyAddress>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getBalance(address: FriendlyAddress) throws -> WalletBalance {
    try fileSystemVault.loadItem(key: address)
  }
  
  func saveWalletBalance(_ walletBalance: WalletBalance, for address: FriendlyAddress) throws {
    try fileSystemVault.saveItem(walletBalance, key: address)
  }
}

protocol WalletBalanceRepository {
  func getWalletBalance(wallet: Wallet) throws -> WalletBalance
  func saveWalletBalance(_ walletBalance: WalletBalance, for wallet: Wallet) throws
}

struct WalletBalanceRepositoryImplementation: WalletBalanceRepository {
  let fileSystemVault: FileSystemVault<WalletBalance, FriendlyAddress>
  
  init(fileSystemVault: FileSystemVault<WalletBalance, FriendlyAddress>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getWalletBalance(wallet: Wallet) throws -> WalletBalance {
    try fileSystemVault.loadItem(key: wallet.friendlyAddress)
  }
  
  func saveWalletBalance(_ walletBalance: WalletBalance,
                         for wallet: Wallet) throws{
    try fileSystemVault.saveItem(walletBalance, key: wallet.friendlyAddress)
  }
}

extension FriendlyAddress: CustomStringConvertible {
  public var description: String {
    toString()
  }
}
