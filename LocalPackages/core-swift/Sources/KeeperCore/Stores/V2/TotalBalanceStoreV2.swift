import Foundation
import TonSwift

public final class TotalBalanceStoreV2: Store<[FriendlyAddress: TotalBalanceState]> {

  private let convertedBalanceStore: ConvertedBalanceStoreV2
  
  init(convertedBalanceStore: ConvertedBalanceStoreV2) {
    self.convertedBalanceStore = convertedBalanceStore
    super.init(state: [:])
    convertedBalanceStore.addObserver(self, notifyOnAdded: true) { observer, state, _ in
      observer.didUpdateConvertedBalances(state)
    }
  }
  
  private func didUpdateConvertedBalances(_ convertedBalances: [FriendlyAddress: ConvertedBalanceState]){
    Task {
      await recalculateTotalBalances(convertedBalances)
    }
  }
  
  private func recalculateTotalBalances(_ convertedBalances: [FriendlyAddress: ConvertedBalanceState]) async {
    await updateState { _ in
      let total = convertedBalances.mapValues {
        self.recalculateTotalBalance($0)
      }
      return StateUpdate(newState: total)
    }
  }
  
  private func recalculateTotalBalance(_ convertedBalanceState: ConvertedBalanceState) -> TotalBalanceState {
    let balance = convertedBalanceState.balance
    let jettonsTotal = balance.jettonsBalance.reduce(Decimal(0)) { partialResult, item in
      return partialResult + item.converted
    }
    let total = jettonsTotal + balance.tonBalance.converted
    switch convertedBalanceState {
    case .current:
      return .current(TotalBalance(amount: total,
                                   currency: balance.currency,
                                   date: balance.date))
    case .previous:
      return .previous(TotalBalance(amount: total,
                                    currency: balance.currency,
                                    date: balance.date))
    }
  }
}
