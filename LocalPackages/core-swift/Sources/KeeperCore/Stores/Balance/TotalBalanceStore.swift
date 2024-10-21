import Foundation
import TonSwift

public final class TotalBalanceStore: StoreV3<TotalBalanceStore.Event, TotalBalanceStore.State> {
  
  public typealias State = [Wallet: TotalBalanceState]
  
  public enum Event {
    case didUpdateTotalBalance(wallet: Wallet)
  }

  private let managedBalanceStore: ManagedBalanceStore
  
  init(managedBalanceStore: ManagedBalanceStore) {
    self.managedBalanceStore = managedBalanceStore
    super.init(state: [:])
    managedBalanceStore.addObserver(self) { observer, event in
      observer.didGetProcessedBalanceStoreEvent(event)
    }
  }
  
  public override func createInitialState() -> State {
    let balanceStates = managedBalanceStore.state
    let total = balanceStates.mapValues {
      self.recalculateTotalBalance($0)
    }
    return total
  }
  
  private func didGetProcessedBalanceStoreEvent(_ event: ManagedBalanceStore.Event) {
    switch event {
    case .didUpdateManagedBalance(let wallet):
      updateTotalBalance(wallet: wallet)
    }
  }
  
  private func updateTotalBalance(wallet: Wallet) {
    updateState { [weak self] state in
      guard let self else { return nil }
      guard let balanceState = managedBalanceStore.state[wallet] else { return nil }
      var updatedState = state
      let walletState = recalculateTotalBalance(balanceState)
      updatedState[wallet] = walletState
      return StateUpdate(newState: updatedState)
    } completion: { _ in
      self.sendEvent(.didUpdateTotalBalance(wallet: wallet))
    }
  }

  private func recalculateTotalBalance(_ balanceState: ManagedBalanceState) -> TotalBalanceState {
    
    func calculateTotal(balance: ManagedBalance) -> TotalBalance {
      let items: [ProcessedBalanceItem] = balance.tonItems.map { .ton($0) } + balance.pinnedItems + balance.unpinnedItems
      let total = items.reduce(Decimal(0)) { partialResult, item in
        return partialResult + item.converted
      }
      return TotalBalance(amount: total, balance: balance, currency: balance.currency, date: balance.date)
    }
    switch balanceState {
    case .current(let processedBalance):
      return .current(calculateTotal(balance: processedBalance))
    case .previous(let processedBalance):
      return .previous(calculateTotal(balance: processedBalance))
    }
  }
}
