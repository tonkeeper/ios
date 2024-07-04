import Foundation
import TonSwift
import BigInt

public final class ConvertedBalanceStoreV2: Store<[FriendlyAddress: ConvertedBalanceState]> {
  private let balanceStore: BalanceStoreV2
  private let tonRatesStore: TonRatesStoreV2
  private let currencyStore: CurrencyStoreV2
  
  init(balanceStore: BalanceStoreV2, 
       tonRatesStore: TonRatesStoreV2,
       currencyStore: CurrencyStoreV2) {
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    super.init(state: [:])
    balanceStore.addObserver(self, notifyOnAdded: true) { observer, balanceState, _ in
      observer.didUpdateBalanceState(balanceState: balanceState)
    }
    tonRatesStore.addObserver(self, notifyOnAdded: true) { observer, rates, _ in
      observer.didUpdateTonRates(tonRates: rates)
    }
  }
  
  private func didUpdateBalanceState(balanceState: [FriendlyAddress: WalletBalanceState]) {
    Task {
      let currency = await currencyStore.getCurrency()
      let rates = await tonRatesStore.getRates()
      await recalculateBalance(
        balanceStates: balanceState,
        tonRates: rates,
        currency: currency
      )
    }
  }
  
  private func didUpdateTonRates(tonRates: [Rates.Rate]) {
    Task {
      let currency = await currencyStore.getCurrency()
      let balanceState = await balanceStore.getState()
      await recalculateBalance(
        balanceStates: balanceState,
        tonRates: tonRates,
        currency: currency
      )
    }
  }
  
  private func recalculateBalance(balanceStates: [FriendlyAddress: WalletBalanceState],
                                  tonRates: [Rates.Rate],
                                  currency: Currency) async {
    await updateState { _ in
      let tonRate = tonRates.first(where: { $0.currency == currency })
      let calculated = balanceStates.mapValues {
        self.recalculateBalance(balanceState: $0, tonRate: tonRate, currency: currency)
      }
      return StateUpdate(newState: calculated)
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
