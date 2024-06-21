import Foundation
import TonSwift

public final class WalletsTotalBalanceStoreV2: Store<WalletsTotalBalanceStoreV2.State> {
  public struct State: Equatable {
    let wallets: [Wallet]
    let balanceStates: [Wallet: WalletBalanceState]
    let currency: Currency
    let tonRates: [Rates.Rate]
    let totalBalances: [Wallet: TotalBalanceState]
  }
  
  private let walletsStore: WalletsStoreV2
  private let balanceStore: WalletsBalanceStoreV2
  private let tonRatesStore: TonRatesStoreV2
  private let currencyStore: CurrencyStoreV2
  private let totalBalanceService: TotalBalanceService
  
  init(walletsStore: WalletsStoreV2, 
       balanceStore: WalletsBalanceStoreV2,
       tonRatesStore: TonRatesStoreV2,
       currencyStore: CurrencyStoreV2,
       totalBalanceService: TotalBalanceService) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.totalBalanceService = totalBalanceService
    super.init(item: State(wallets: [],
                           balanceStates: [:],
                           currency: .USD,
                           tonRates: [],
                           totalBalances: [:]))
    updateTotalBalances()
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, _ in
      observer.updateTotalBalances()
    }
    balanceStore.addObserver(self, notifyOnAdded: false) { observer, _ in
      observer.updateTotalBalances()
    }
    currencyStore.addObserver(self, notifyOnAdded: false) { observer, _ in
      observer.updateTotalBalances()
    }
    tonRatesStore.addObserver(self, notifyOnAdded: false) { observer, _ in
      observer.updateTotalBalances()
    }
  }
}

private extension WalletsTotalBalanceStoreV2 {
  func updateTotalBalances() {
    Task {
      let currency = await currencyStore.getCurrency()
      let wallets = await walletsStore.getItem().wallets
      var balanceStates = [Wallet: WalletBalanceState]()
      for wallet in wallets {
        balanceStates[wallet] = await balanceStore.getBalanceState(wallet: wallet)
      }
      let tonRates = await tonRatesStore.getRates()
      await updateItem { state in
        if currency != state.currency {
          let totalBalances = self.recalculateTotalBalances(
            balanceStates: balanceStates,
            currency: currency,
            rates: tonRates
          )
          return State(
            wallets: wallets,
            balanceStates: balanceStates,
            currency: currency,
            tonRates: tonRates,
            totalBalances: totalBalances
          )
        }
        
        if tonRates != state.tonRates {
          let totalBalances = self.recalculateTotalBalances(
            balanceStates: balanceStates,
            currency: currency,
            rates: tonRates
          )
          return State(
            wallets: wallets,
            balanceStates: balanceStates,
            currency: currency,
            tonRates: tonRates,
            totalBalances: totalBalances
          )
        }
        
        if wallets != state.wallets {
          let walletsDiff = Set(wallets).symmetricDifference(Set(state.wallets))
          let diffBalanceStates = balanceStates.filter { walletsDiff.contains($0.key) }
          let diffTotalBalances = self.recalculateTotalBalances(
            balanceStates: diffBalanceStates,
            currency: currency,
            rates: tonRates
          )
          let totalBalances = state.totalBalances.merging(diffTotalBalances) { _, diff in
            return diff
          }
          return State(
            wallets: wallets,
            balanceStates: balanceStates,
            currency: currency,
            tonRates: tonRates,
            totalBalances: totalBalances
          )
        }
        
        if balanceStates != state.balanceStates {
          let changedBalances = balanceStates.filter { $0.value != state.balanceStates[$0.key] }
          let changedTotalBalances = self.recalculateTotalBalances(
            balanceStates: changedBalances,
            currency: currency,
            rates: tonRates
          )
          let totalBalances = state.totalBalances.merging(changedTotalBalances) { _, diff in
            return diff
          }
          return State(
            wallets: wallets,
            balanceStates: balanceStates,
            currency: currency,
            tonRates: tonRates,
            totalBalances: totalBalances
          )
        }
        return state
      }
    }
  }
  
  func recalculateTotalBalances(
    balanceStates: [Wallet: WalletBalanceState],
    currency: Currency,
    rates: [Rates.Rate]
  ) -> [Wallet: TotalBalanceState] {
    balanceStates.compactMapValues { balanceState -> TotalBalanceState in
      let totalBalance = totalBalanceService.calculateTotalBalance(
        balance: balanceState.walletBalance.balance,
        currency: currency,
        rates: Rates(ton: rates, jettonsRates: [])
      )
      switch balanceState {
      case .current:
        return .current(totalBalance)
      case .previous:
        return .previous(totalBalance)
      }
    }
  }
}
