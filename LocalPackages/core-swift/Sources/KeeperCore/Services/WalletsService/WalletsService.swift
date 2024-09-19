import Foundation
import CoreComponents

enum WalletsServiceError: Swift.Error {
  case emptyWallets
  case walletNotAdded
  case incorrectMoveFromIndex
  case incorrectMoveToIndex
  case incorrectActiveWalletIdentity
}

public enum WalletsServiceDeleteWalletResult {
  case deletedWallet
  case deletedAll
}

public protocol WalletsService {
  func getWallets() throws -> [Wallet]
  func getActiveWallet() throws -> Wallet
  func addWallets(_ wallets: [Wallet]) throws
  func setWalletActive(_ wallet: Wallet) throws
  func moveWallet(fromIndex: Int, toIndex: Int) throws
  func updateWallet(wallet: Wallet, metaData: WalletMetaData) throws
  func updateWallet(wallet: Wallet, setupSettings: WalletSetupSettings) throws 
  func deleteWallet(wallet: Wallet) throws -> WalletsServiceDeleteWalletResult
}

final class WalletsServiceImplementation: WalletsService {
  let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
  }
  
  func getWallets() throws -> [Wallet] {
    try keeperInfoRepository.getKeeperInfo().wallets
  }
  
  func getActiveWallet() throws -> Wallet {
    let keeperInfo = try keeperInfoRepository.getKeeperInfo()
    return keeperInfo.currentWallet
  }
  
  func addWallets(_ wallets: [Wallet]) throws {
  }
  
  func setWalletActive(_ wallet: Wallet) throws {
    
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) throws  {
    
  }
  
  func updateWallet(wallet: Wallet, metaData: WalletMetaData) throws {
    
  }
  
  func updateWallet(wallet: Wallet, setupSettings: WalletSetupSettings) throws {
    
  }

  func deleteWallet(wallet: Wallet) throws -> WalletsServiceDeleteWalletResult {
    .deletedAll
  }
}
