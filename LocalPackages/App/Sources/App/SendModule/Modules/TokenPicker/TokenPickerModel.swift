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
  
  var didUpdateState: ((State?) -> Void)?
  
  private let wallet: Wallet
  private let selectedToken: Token
  private let balanceStore: ConvertedBalanceStore
  
  init(wallet: Wallet, 
       selectedToken: Token,
       balanceStore: ConvertedBalanceStore) {
    self.wallet = wallet
    self.selectedToken = selectedToken
    self.balanceStore = balanceStore
    
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateConvertedBalance(let wallet): 
        guard wallet == observer.wallet else { return }
        Task {
          await observer.didUpdateBalanceState()
        }
      }
    }
  }
  
  func getState() -> State? {
    let balanceState = balanceStore.state[wallet]
    let state = getState(balanceState: balanceState, scrollToSelected: false)
    return state
  }
}

private extension TokenPickerModel {
  func didUpdateBalanceState() async {
    let balanceState = balanceStore.state[wallet]
    let state = getState(balanceState: balanceState, scrollToSelected: false)
    self.didUpdateState?(state)
  }
  
  func getState(balanceState: ConvertedBalanceState?, scrollToSelected: Bool) -> State? {
    guard let balance = balanceState?.balance else { return nil}
    return State(
      tonBalance: balance.tonBalance,
      jettonBalances: balance.jettonsBalance.filter { !$0.jettonBalance.quantity.isZero },
      selectedToken: selectedToken,
      scrollToSelected: scrollToSelected
    )
  }
}
