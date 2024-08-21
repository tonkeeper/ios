import Foundation
import CoreComponents
import TonSwift

protocol AccountNFTsManagementRepository {
  func getState(wallet: Wallet) -> NFTsManagementState
  func setState(_ state: NFTsManagementState, wallet: Wallet) throws
}

struct AccountNFTsManagementRepositoryImplementation: AccountNFTsManagementRepository {
  let fileSystemVault: FileSystemVault<NFTsManagementState, FriendlyAddress>
  
  init(fileSystemVault: FileSystemVault<NFTsManagementState, FriendlyAddress>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getState(wallet: Wallet) -> NFTsManagementState {
    do {
      return try fileSystemVault.loadItem(key: wallet.friendlyAddress)
    } catch {
      return NFTsManagementState(nftStates: [:])
    }
  }
  
  func setState(_ state: NFTsManagementState, wallet: Wallet) throws {
    try fileSystemVault.saveItem(state, key: wallet.friendlyAddress)
  }
}
