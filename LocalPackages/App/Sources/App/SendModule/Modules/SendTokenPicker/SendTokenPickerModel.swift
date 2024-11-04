import Foundation
import KeeperCore
import TonSwift

final class SendTokenPickerModel: TokenPickerModel {

  var didUpdateState: ((TokenPickerModelState?) -> Void)?

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
  
  func getState() -> TokenPickerModelState? {
    let balanceState = balanceStore.state[wallet]
    let state = getState(balanceState: balanceState, scrollToSelected: false)
    return state
  }
}

private extension SendTokenPickerModel {
  func didUpdateBalanceState() async {
    let balanceState = balanceStore.state[wallet]
    let state = getState(balanceState: balanceState, scrollToSelected: false)
    self.didUpdateState?(state)
  }
  
  func getState(balanceState: ConvertedBalanceState?, scrollToSelected: Bool) -> TokenPickerModelState? {
    guard let balance = balanceState?.balance else { return nil}
    return TokenPickerModelState(
      tonBalance: balance.tonBalance,
      jettonBalances: balance.jettonsBalance.filter { !$0.jettonBalance.quantity.isZero },
      selectedToken: selectedToken,
      scrollToSelected: scrollToSelected
    )
  }
}
