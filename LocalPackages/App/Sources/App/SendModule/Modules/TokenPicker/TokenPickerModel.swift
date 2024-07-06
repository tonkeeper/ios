import Foundation
import KeeperCore
import TonSwift

final class TokenPickerModel {
  
  struct State {
    let tonBalance: ConvertedTonBalance
    let jettonBalances: [ConvertedJettonBalance]
    let selectedToken: Token
    let scrollToSelected: Bool
  }
  
  var didUpdateState: ((State) -> Void)? {
    didSet {
      Task {
        await self.actor.addTask(block: {
          let balanceState = await self.balanceStore.getState()
          guard let state = await self.getState(balanceState: balanceState,
                                                scrollToSelected: true) else { return }
          self.didUpdateState?(state)
        })
      }
    }
  }
  
  private let actor = SerialActor<Void>()
  
  private let wallet: Wallet
  private let selectedToken: Token
  private let balanceStore: ConvertedBalanceStoreV2
  
  init(wallet: Wallet, 
       selectedToken: Token,
       balanceStore: ConvertedBalanceStoreV2) {
    self.wallet = wallet
    self.selectedToken = selectedToken
    self.balanceStore = balanceStore
    
    balanceStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
        Task {
          await observer.didUpdateBalanceState(balanceState: newState,
                                               oldBalanceState: oldState)
        }
      }
  }
}

private extension TokenPickerModel {
  func didUpdateBalanceState(balanceState: [FriendlyAddress: ConvertedBalanceState],
                             oldBalanceState: [FriendlyAddress: ConvertedBalanceState]?) async {
    guard let state = await getState(balanceState: balanceState, scrollToSelected: false) else { return }
    self.didUpdateState?(state)
  }
  
  func getState(balanceState: [FriendlyAddress: ConvertedBalanceState], scrollToSelected: Bool) async -> State? {
    guard let address = try? wallet.friendlyAddress else { return nil }
    guard let balance = balanceState[address]?.balance else { return nil }
    return State(
      tonBalance: balance.tonBalance,
      jettonBalances: balance.jettonsBalance,
      selectedToken: selectedToken,
      scrollToSelected: scrollToSelected
    )
  }
}
