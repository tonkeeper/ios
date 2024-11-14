import Foundation
import TonSwift

public final class WalletNFTsManagementStore: Store<WalletNFTsManagementStore.Event, NFTsManagementState> {
  public enum Event {
    case didUpdateState(wallet: Wallet)
  }
  
  private let wallet: Wallet
  private let accountNFTsManagementRepository: AccountNFTsManagementRepository
  
  init(wallet: Wallet, 
       accountNFTsManagementRepository: AccountNFTsManagementRepository) {
    self.wallet = wallet
    self.accountNFTsManagementRepository = accountNFTsManagementRepository
    super.init(state: NFTsManagementState(nftStates: [:]))
  }
  
  public override func createInitialState() -> NFTsManagementState {
    accountNFTsManagementRepository.getState(wallet: wallet)
  }

  // MARK: -  async

  public func hideItem(_ item: NFTManagementItem) async {
    await withCheckedContinuation { continuation in
      hideItem(item) {
        continuation.resume()
      }
    }
  }
  
  public func showItem(_ item: NFTManagementItem) async {
    await withCheckedContinuation { continuation in
      showItem(item) {
        continuation.resume()
      }
    }
  }

  public func approveItem(_ item: NFTManagementItem) async {
    await withCheckedContinuation { continuation in
      approveItem(item) {
        continuation.resume()
      }
    }
  }

  public func spamItem(_ item: NFTManagementItem) async {
    await withCheckedContinuation { continuation in
      spamItem(item) {
        continuation.resume()
      }
    }
  }

  public func hideItem(_ item: NFTManagementItem,
                       completion: (() -> Void)? = nil) {
    updateState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[item] = .hidden
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return WalletNFTsManagementStore.StateUpdate(newState: updatedState)
    } completion: { [weak self, wallet] _ in
      self?.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }
  
  public func showItem(_ item: NFTManagementItem,
                       completion: (() -> Void)? = nil) {
    updateState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[item] = .visible
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return WalletNFTsManagementStore.StateUpdate(newState: updatedState)
    } completion: { [weak self, wallet] _ in
      self?.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }

  public func approveItem(_ item: NFTManagementItem,
                          completion: (() -> Void)? = nil) {
    updateState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[item] = .approved
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return WalletNFTsManagementStore.StateUpdate(newState: updatedState)
    } completion: { [weak self, wallet] _ in
      self?.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }

  public func spamItem(_ item: NFTManagementItem,
                       completion: (() -> Void)? = nil) {
    updateState { [accountNFTsManagementRepository, wallet] state in
      var updatedNFTStates = state.nftStates
      updatedNFTStates[item] = .spam
      let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
      try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
      return WalletNFTsManagementStore.StateUpdate(newState: updatedState)
    } completion: { [weak self, wallet] _ in
      self?.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }
}
