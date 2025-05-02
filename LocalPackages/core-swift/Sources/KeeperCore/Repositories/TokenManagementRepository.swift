import Foundation
import CoreComponents
import TonSwift
import TronSwift

protocol TokenManagementRepository {
  func getState(wallet: Wallet) -> TokenManagementState
  func setState(_ state: TokenManagementState, wallet: Wallet) throws
}

struct TokenManagementRepositoryImplementation: TokenManagementRepository {
  let fileSystemVault: FileSystemVault<TokenManagementState, FriendlyAddress>
  
  init(fileSystemVault: FileSystemVault<TokenManagementState, FriendlyAddress>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getState(wallet: Wallet) -> TokenManagementState {
    do {
      return try fileSystemVault.loadItem(key: wallet.friendlyAddress)
    } catch {
      return TokenManagementState(pinnedItems: Constants.defaultPinnedItems,
                                  unpinnedItems: [],
                                  hiddenState: [:])
    }
  }
  
  func setState(_ state: TokenManagementState, wallet: Wallet) throws {
    try fileSystemVault.saveItem(state, key: wallet.friendlyAddress)
  }
  
  private enum Constants {
    static var defaultPinnedItems = [JettonMasterAddress.tonUSDT.toRaw(), TronSwift.USDT.address.base58]
  }
}
