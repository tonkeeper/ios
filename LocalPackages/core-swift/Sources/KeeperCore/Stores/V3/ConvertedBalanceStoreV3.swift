import Foundation
import TonSwift
import BigInt

public final class ConvertedBalanceStoreV3: StoreV3<ConvertedBalanceStoreV3.Event, ConvertedBalanceStoreV3.State> {
  public typealias State = [Wallet: ConvertedBalanceState]
  public enum Event {
    case didUpdateConvertedBalance(state: ConvertedBalanceState, wallet: Wallet)
  }
  
  private let walletsStore: WalletsStoreV3
  private let balanceStore: BalanceStoreV3
  private let tonRatesStore: TonRatesStoreV3
  private let currencyStore: CurrencyStoreV3
  
  init(walletsStore: WalletsStoreV3,
       balanceStore: BalanceStoreV3,
       tonRatesStore: TonRatesStoreV3,
       currencyStore: CurrencyStoreV3) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    super.init(state: [:])
    balanceStore.addObserver(self) { observer, event in
      observer.didGetBalanceStoreEvent(event)
    }
    tonRatesStore.addObserver(self) { observer, event in
      observer.didGetTonRatesStoreEvent(event)
    }
  }
  
  public override var initialState: State {
    let wallets = walletsStore.wallets
    let balanceStates = balanceStore.getState()
    let tonRates = tonRatesStore.getState()
    let currency = currencyStore.getState()
    
    var state = State()
    for wallet in wallets {
      guard let walletBalanceState = balanceStates[wallet] else { continue }
      state[wallet] = recalculateBalance(
        balanceState: walletBalanceState,
        tonRate: tonRates.first(where: { $0.currency == currency }),
        currency: currency
      )
    }
    return state
  }
  
  private func didGetBalanceStoreEvent(_ event: BalanceStoreV3.Event) {
    Task {
      switch event {
      case .didUpdateBalanceState(let wallet, _):
        await updateState(wallet: wallet)
      }
    }
  }
  
  private func didGetTonRatesStoreEvent(_ event: TonRatesStoreV3.Event) {
    Task {
      switch event {
      case .didUpdateTonRates:
        let wallets = walletsStore.wallets
        for wallet in wallets {
          await updateState(wallet: wallet)
        }
      }
    }
  }
  
  private func updateState(wallet: Wallet) async {
    var convertedBalanceState: ConvertedBalanceState?
    await setState { state in
      guard let balanceState = self.balanceStore.getState()[wallet] else {
        return nil
      }
      let tonRates = self.tonRatesStore.getState()
      let currency = self.currencyStore.getState()
      
      convertedBalanceState = self.recalculateBalance(
        balanceState: balanceState,
        tonRate: tonRates.first(where: { $0.currency == currency }),
        currency: currency
      )
      var updatedState = state
      updatedState[wallet] = convertedBalanceState
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      guard let convertedBalanceState else { return }
      self.sendEvent(.didUpdateConvertedBalance(state: convertedBalanceState, wallet: wallet))
    }
  }
  
  private func recalculateBalance(balanceState: WalletBalanceState,
                                  tonRate: Rates.Rate?,
                                  currency: Currency) -> ConvertedBalanceState {
    let balance = balanceState.walletBalance
    
    let tonItem = calculateTonBalance(
      balance.balance.tonBalance,
      tonRate: tonRate
    )
    
    let jettonItems = balance.balance.jettonsBalance.map {
      calculateJettonBalance($0, currency: currency)
    }
    
    let stackingItems = balance.stacking.map {
      calculateStakingBalance(
        $0,
        tonRate: tonRate
      )
    }
    
    let convertedBalance = ConvertedBalance(
      date: balance.date,
      currency: currency,
      tonBalance: tonItem,
      jettonsBalance: jettonItems,
      stackingBalance: stackingItems
    )
    
    switch balanceState {
    case .current:
      return .current(convertedBalance)
    case .previous:
      return .previous(convertedBalance)
    }
  }
  
  private func calculateTonBalance(_ tonBalance: TonBalance,
                                   tonRate: Rates.Rate?) -> ConvertedTonBalance {
    let converted: Decimal
    let price: Decimal
    let diff: String?
    if let tonRate = tonRate {
      converted = RateConverter().convertToDecimal(
        amount: BigUInt(tonBalance.amount),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      diff = tonRate.diff24h
      price = tonRate.rate
    } else {
      converted = 0
      diff = nil
      price = 0
    }

    return ConvertedTonBalance(
      tonBalance: tonBalance,
      converted: converted,
      price: price,
      diff: diff
    )
  }
  
  private func calculateJettonBalance(_ jettonBalance: JettonBalance,
                                      currency: Currency) -> ConvertedJettonBalance {
    let converted: Decimal
    let price: Decimal
    let diff: String?
    if let rate = jettonBalance.rates[currency] {
      converted = RateConverter().convertToDecimal(
        amount: jettonBalance.quantity,
        amountFractionLength: jettonBalance.item.jettonInfo.fractionDigits,
        rate: rate
      )
      diff = rate.diff24h
      price = rate.rate
    } else {
      converted = 0
      diff = nil
      price = 0
    }

    return ConvertedJettonBalance(
      jettonBalance: jettonBalance,
      converted: converted,
      price: price,
      diff: diff
    )
  }
  
  private func calculateStakingBalance(_ accountStackingInfo: AccountStackingInfo,
                                       tonRate: Rates.Rate?) -> ConvertedStakingBalance {
    var amountConverted: Decimal = 0
    var pendingDepositConverted: Decimal = 0
    var pendingWithdrawConverted: Decimal = 0
    var readyWithdrawConverted: Decimal = 0
    var price: Decimal = 0
    if let tonRate = tonRate {
      amountConverted = RateConverter().convertToDecimal(
        amount: BigUInt(accountStackingInfo.amount),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      pendingDepositConverted = RateConverter().convertToDecimal(
        amount: BigUInt(accountStackingInfo.pendingDeposit),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      pendingWithdrawConverted = RateConverter().convertToDecimal(
        amount: BigUInt(accountStackingInfo.pendingWithdraw),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      readyWithdrawConverted = RateConverter().convertToDecimal(
        amount: BigUInt(accountStackingInfo.readyWithdraw),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      
      price = tonRate.rate
    }
    
    return ConvertedStakingBalance(
      stackingInfo: accountStackingInfo,
      amountConverted: amountConverted,
      pendingDepositConverted: pendingDepositConverted,
      pendingWithdrawConverted: pendingWithdrawConverted,
      readyWithdrawConverted: readyWithdrawConverted,
      price: price
    )
  }
}
