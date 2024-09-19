import Foundation
import TonSwift

public final class WalletNFTsManagementStore: StoreV3<WalletNFTsManagementStore.Event, NFTsManagementState> {
  public enum Event {
    case didUpdateState(wallet: Wallet)
  }

  public enum NFTState: Equatable {
    case visible
    case hidden
  }
  
  private let wallet: Wallet
  private let accountNFTsManagementRepository: AccountNFTsManagementRepository
  
  init(wallet: Wallet, 
       accountNFTsManagementRepository: AccountNFTsManagementRepository) {
    self.wallet = wallet
    self.accountNFTsManagementRepository = accountNFTsManagementRepository
    super.init(state: NFTsManagementState(nftStates: [:]))
  }
  
  public override var initialState: NFTsManagementState {
    accountNFTsManagementRepository.getState(wallet: wallet)
  }
  
  public func hideItem(_ item: NFTManagementItem) async {
    await setState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[item] = .hidden
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return WalletNFTsManagementStore.StateUpdate(newState: updatedState)
    } notify: { [wallet] _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
    }
  }
  
  public func showItem(_ item: NFTManagementItem) async {
    await setState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[item] = .visible
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return WalletNFTsManagementStore.StateUpdate(newState: updatedState)
    } notify: { [wallet] _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
    }
  }
}
