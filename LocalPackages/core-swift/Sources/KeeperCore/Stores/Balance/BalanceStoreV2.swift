import Foundation
import TonSwift

public final class BalanceStoreV2: StoreUpdated<[FriendlyAddress: WalletBalanceState]> {
  private let walletsStore: WalletsStore
  private let repository: WalletBalanceRepositoryV2
  
  init(walletsStore: WalletsStore,
       repository: WalletBalanceRepositoryV2) {
    self.walletsStore = walletsStore
    self.repository = repository
    super.init(state: [:])
    walletsStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
        observer.didUpdateWalletsStoreState(walletsState: newState)
      }
  }
  
  public func setBalanceState(_ balanceState: WalletBalanceState?, address: FriendlyAddress, completion: (() -> Void)?) {
    updateState { [repository] state in
      if let balance = balanceState?.walletBalance {
        try? repository.saveWalletBalance(balance, for: address)
      }
      var updatedState = state
      updatedState[address] = balanceState
      return StateUpdate(newState: updatedState)
    } completion: {
      completion?()
    }
  }
  
  public func setBalanceState(_ balanceState: WalletBalanceState?, address: FriendlyAddress) async {
    await updateState { [repository] state in
      if let balance = balanceState?.walletBalance {
        try? repository.saveWalletBalance(balance, for: address)
      }
      var updatedState = state
      updatedState[address] = balanceState
      return StateUpdate(newState: updatedState)
    }
  }
  
  public override func getInitialState() -> [FriendlyAddress: WalletBalanceState] {
    let wallets = walletsStore.getState().wallets
    let addresses = wallets.compactMap { try? $0.friendlyAddress }
    var state = [FriendlyAddress: WalletBalanceState]()
    addresses.forEach { address in
      do {
        let balance = try repository.getBalance(address: address)
        state[address] = .previous(balance)
      } catch {
        state[address] = nil
      }
    }
    return state
  }
  
  private func didUpdateWalletsStoreState(walletsState: WalletsState) {
    updateState { [repository] state in
      var updatedState = [FriendlyAddress: WalletBalanceState]()
      
      let wallets = walletsState.wallets
      let addresses = wallets.compactMap { try? $0.friendlyAddress }
      addresses.forEach { address in
        if let balanceState = state[address] {
          updatedState[address] = balanceState
        } else if let balanceState = try? repository.getBalance(address: address) {
          updatedState[address] = .previous(balanceState)
        } else {
          updatedState[address] = nil
        }
      }
      return StateUpdate(newState: updatedState)
    }
  }
}
