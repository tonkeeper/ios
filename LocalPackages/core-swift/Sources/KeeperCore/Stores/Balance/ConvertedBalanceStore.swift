import Foundation
import TonSwift
import BigInt

public final class ConvertedBalanceStore: Store<ConvertedBalanceStore.Event, ConvertedBalanceStore.State> {
  public typealias State = [Wallet: ConvertedBalanceState]
  public enum Event {
    case didUpdateConvertedBalance(wallet: Wallet)
  }
  
  private let walletsStore: WalletsStore
  private let balanceStore: BalanceStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  
  init(walletsStore: WalletsStore,
       balanceStore: BalanceStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    super.init(state: [:])
    setupObservations()
  }
  
  public override func createInitialState() -> State {
    calculateState(wallets: walletsStore.wallets)
  }
  
  private func calculateState(wallets: [Wallet]) -> State {
    guard !wallets.isEmpty else { return [:] }
    let balanceStates = balanceStore.state
    let tonRates = tonRatesStore.state
    let currency = currencyStore.state
    
    let rates = tonRates.first(where: { $0.currency == currency })
    
    var state = State()
    for wallet in wallets {
      guard let walletBalanceState = balanceStates[wallet] else { continue }
      state[wallet] = recalculateBalance(
        balanceState: walletBalanceState,
        tonRate: rates,
        currency: currency
      )
    }
    return state
  }
  
  private func setupObservations() {
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateBalanceState(let wallet):
        observer.updateState(wallets: [wallet])
      }
    }
    tonRatesStore.addObserver(self) { observer, event in
      observer.updateState(wallets: observer.walletsStore.wallets)
    }
  }
  
  private func updateState(wallets: [Wallet]) {
    updateState { [weak self] state in
      guard let self else { return nil }
      let walletsState = self.calculateState(wallets: wallets)
      let updatedState = state.merging(walletsState, uniquingKeysWith: { $1 })
      return StateUpdate(newState: updatedState)
    } completion: { [weak self] _ in
      wallets.forEach { self?.sendEvent(.didUpdateConvertedBalance(wallet: $0)) }
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
