import Foundation
import TonSwift

public final class TotalBalanceStore: StoreV3<TotalBalanceStore.Event, TotalBalanceStore.State> {
  
  public typealias State = [Wallet: TotalBalanceState]
  
  public enum Event {
    case didUpdateTotalBalance(state: TotalBalanceState, wallet: Wallet)
  }

  private let managedBalanceStore: ManagedBalanceStore
  
  init(managedBalanceStore: ManagedBalanceStore) {
    self.managedBalanceStore = managedBalanceStore
    super.init(state: [:])
    managedBalanceStore.addObserver(self) { observer, event in
      observer.didGetProcessedBalanceStoreEvent(event)
    }
  }
  
  public override var initialState: State {
    let balanceStates = managedBalanceStore.getState()
    let total = balanceStates.mapValues {
      self.recalculateTotalBalance($0)
    }
    return total
  }
  
  private func didGetProcessedBalanceStoreEvent(_ event: ManagedBalanceStore.Event) {
    switch event {
    case .didUpdateManagedBalance(_ , let wallet):
      Task {
        await recalculateTotalBalance(wallet: wallet)
      }
    }
  }
  
  private func recalculateTotalBalance(wallet: Wallet) async {
    guard let balanceState = await managedBalanceStore.getState()[wallet] else { return }
    let totalBalanceState = recalculateTotalBalance(balanceState)
    await setState { state in
      var updatedState = state
      updatedState[wallet] = totalBalanceState
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateTotalBalance(state: totalBalanceState, wallet: wallet))
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
