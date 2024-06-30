import Foundation
import TonSwift

public final class BalanceStoreV2: Store<[FriendlyAddress: WalletBalanceState]> {
  
  private let walletsStore: WalletsStoreV2
  private let repository: WalletBalanceRepositoryV2
  
  init(walletsStore: WalletsStoreV2, 
       repository: WalletBalanceRepositoryV2) {
    self.walletsStore = walletsStore
    self.repository = repository
    super.init(state: [:])
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState, _ in
      observer.didUpdateWalletsState(walletsState)
    }
  }
  
  public func getBalanceState(address: FriendlyAddress) async -> WalletBalanceState? {
    let state = await getState()
    return state[address]
  }
  
  public func setBalanceState(_ balanceState: WalletBalanceState?,
                              address: FriendlyAddress) async {
    await updateState { [repository] state in
      var state = state
      state[address] = balanceState
      if let balance = balanceState?.walletBalance {
        try? repository.saveWalletBalance(balance, for: address)
      }
      return StateUpdate(newState: state)
    }
  }
  
  private func didUpdateWalletsState(_ walletsState: WalletsState) {
    Task {
      await updateState { [repository] state in
        let walletAddresses = walletsState.wallets.compactMap { try? $0.friendlyAddress }
        var newState = [FriendlyAddress: WalletBalanceState]()
        walletAddresses.forEach { address in
          if let balanceState = state[address] {
            newState[address] = balanceState
          } else if let cachedBalance = try? repository.getBalance(address: address) {
            newState[address] = .previous(cachedBalance)
          }
        }
        return StateUpdate(newState: newState)
      }
    }
  }
}
