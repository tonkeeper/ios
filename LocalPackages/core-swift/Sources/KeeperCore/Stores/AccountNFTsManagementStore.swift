import Foundation
import TonSwift

public final class AccountNFTsManagementStore: StoreUpdated<NFTsManagementState> {
  
  public struct State: Equatable {
    public let nftStates: [Address: NFTState]
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
  
  public override func getInitialState() -> NFTsManagementState {
    accountNFTsManagementRepository.getState(wallet: wallet)
  }
  
  public func hideItem(address: Address) async {
    await updateState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[address] = .hidden
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return AccountNFTsManagementStore.StateUpdate(newState: updatedState)
    }
  }
  
  public func showItem(address: Address) async {
    await updateState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[address] = .visible
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return AccountNFTsManagementStore.StateUpdate(newState: updatedState)
    }
  }
}
