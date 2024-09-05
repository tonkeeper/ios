import Foundation
import TonSwift

public final class TotalBalanceStoreV3: StoreV3<TotalBalanceStoreV3.Event, TotalBalanceStoreV3.State> {
  
  public typealias State = [Wallet: TotalBalanceState]
  
  public enum Event {
    case didUpdateTotalBalance(state: TotalBalanceState, wallet: Wallet)
  }

  private let processedBalanceStore: ProcessedBalanceStoreV3
  
  init(processedBalanceStore: ProcessedBalanceStoreV3) {
    self.processedBalanceStore = processedBalanceStore
    super.init(state: [:])
    processedBalanceStore.addObserver(self) { observer, event in
      observer.didGetProcessedBalanceStoreEvent(event)
    }
  }
  
  public override var initialState: State {
    let balanceStates = processedBalanceStore.getState()
    let total = balanceStates.mapValues {
      self.recalculateTotalBalance($0)
    }
    return total
  }
  
  private func didGetProcessedBalanceStoreEvent(_ event: ProcessedBalanceStoreV3.Event) {
    switch event {
    case .didUpdateProccessedBalance(_, let wallet):
      Task {
        await recalculateTotalBalance(wallet: wallet)
      }
    }
  }
  
  private func recalculateTotalBalance(wallet: Wallet) async {
    guard let balanceState = await processedBalanceStore.getState()[wallet] else { return }
    let totalBalanceState = recalculateTotalBalance(balanceState)
    await setState { state in
      var updatedState = state
      updatedState[wallet] = totalBalanceState
      return StateUpdate(newState: updatedState)
    } notify: {
      self.sendEvent(.didUpdateTotalBalance(state: totalBalanceState, wallet: wallet))
    }
  }
  
  private func recalculateTotalBalance(_ balanceState: ProcessedBalanceState) -> TotalBalanceState {
    
    func calculateTotal(balance: ProcessedBalance) -> TotalBalance {
      let total = balance.items.reduce(Decimal(0)) { partialResult, item in
        return partialResult + item.converted
      }
      return TotalBalance(amount: total, balance: balance, currency: balance.currency, date: balance.date)
    }
    switch balanceState {
    case .none:
      return .none
    case .current(let processedBalance):
      return .current(calculateTotal(balance: processedBalance))
    case .previous(let processedBalance):
      return .previous(calculateTotal(balance: processedBalance))
    }
  }
}
