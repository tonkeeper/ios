import Foundation
import TonSwift

public final class BalanceStore: StoreV3<BalanceStore.Event, BalanceStore.State> {
  public typealias State = [Wallet: WalletBalanceState]
  
  public enum Event {
    case didUpdateBalanceState(wallet: Wallet, WalletBalanceState)
  }
  
  private let walletsStore: WalletsStore
  private let repository: WalletBalanceRepositoryV2
  
  init(walletsStore: WalletsStore,
       repository: WalletBalanceRepositoryV2) {
    self.walletsStore = walletsStore
    self.repository = repository
    super.init(state: [:])
    walletsStore.addObserver(self) { observer, event in
      Task {
        switch event {
        case .didAddWallets(let wallets):
          await observer.didAddWallets(wallets)
        default: break
        }
      }
    }
  }
  
  public override var initialState: State {
    let wallets = walletsStore.wallets
    var state = State()
    wallets.forEach { wallet in
      do {
        let balance = try repository.getBalance(address: wallet.friendlyAddress)
        state[wallet] = .previous(balance)
      } catch {
        state[wallet] = nil
      }
    }
    return state
  }
  
  public func setBalanceState(_ balanceState: WalletBalanceState, wallet: Wallet) async {
    await setState { state in
      try? self.repository.saveWalletBalance(balanceState.walletBalance, 
                                             for: wallet.friendlyAddress)
      var updatedState = state
      updatedState[wallet] = balanceState
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateBalanceState(wallet: wallet, balanceState))
    }
  }
  
  private func didAddWallets(_ wallets: [Wallet]) async {
    var observersActions = [(() -> Void)]()
    await setState { [repository] state in
      var updatedState = state
      wallets.forEach { wallet in
        guard state[wallet] == nil else { return }
        do {
          let balance = try repository.getBalance(address: wallet.friendlyAddress)
          updatedState[wallet] = .previous(balance)
          observersActions.append({
            self.sendEvent(.didUpdateBalanceState(wallet: wallet, .previous(balance)))
          })
        } catch {
          updatedState[wallet] = nil
        }
      }
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      observersActions.forEach { $0() }
    }
  }
}
