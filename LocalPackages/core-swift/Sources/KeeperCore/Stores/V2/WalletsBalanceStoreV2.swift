import Foundation
import TonSwift

public final class WalletsBalanceStoreV2: Store<WalletsBalanceStoreV2.State> {
  
  public struct State: Equatable {
    let balances: [FriendlyAddress: WalletBalanceState]
  }
  
  private let walletsStore: WalletsStoreV2
  private let repository: WalletBalanceRepositoryV2
  
  init(walletsStore: WalletsStoreV2,
       repository: WalletBalanceRepositoryV2) {
    self.walletsStore = walletsStore
    self.repository = repository
    super.init(item: State(balances: [:]))
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState in
      observer.didUpdateWalletsState(walletsState)
    }
  }
  
  public func setBalanceState(_ balanceState: WalletBalanceState?,
                              wallet: Wallet) async {
    guard let address = try? wallet.friendlyAddress else { return }
    await updateItem { [repository] state in
      var balances = state.balances
      balances[address] = balanceState
      if let balanceState {
        try? repository.saveWalletBalance(balanceState.walletBalance, for: address)
      }
      return State(balances: balances)
    }
  }
  
  public func getBalanceState(wallet: Wallet) async -> WalletBalanceState? {
    guard let address = try? wallet.friendlyAddress else { return nil }
    let state = await getItem()
    return state.balances[address]
  }

  private func didUpdateWalletsState(_ walletsState: WalletsState) {
    Task {
      await updateItem { [repository] state in
        var balances = state.balances
        let addresses = walletsState.wallets.compactMap { try? $0.friendlyAddress }
        for address in addresses {
          if balances[address] == nil,
             let balance = try? repository.getBalance(address: address)  {
            balances[address] = .previous(balance)
          }
        }
        return State(balances: balances)
      }
    }
  }
}
