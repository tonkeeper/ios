import Foundation
import TonSwift
import BigInt

public enum ProcessedBalanceState: Equatable {
  case current(ProcessedBalance)
  case previous(ProcessedBalance)
  
  public var balance: ProcessedBalance {
    switch self {
    case .current(let balance):
      return balance
    case .previous(let balance):
      return balance
    }
  }
}

public final class ProcessedBalanceStore: Store<ProcessedBalanceStore.Event, ProcessedBalanceStore.State> {
  public typealias State = [Wallet: ProcessedBalanceState]
  
  public enum Event {
    case didUpdateProccessedBalance(wallet: Wallet)
  }
  
  private let walletsStore: WalletsStore
  private let balanceStore: BalanceStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let stakingPoolsStore: StakingPoolsStore
  
  init(walletsStore: WalletsStore,
       balanceStore: BalanceStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       stakingPoolsStore: StakingPoolsStore) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.stakingPoolsStore = stakingPoolsStore
    super.init(state: [:])
    setupObservers()
  }
  
  public override func createInitialState() -> State {
    let wallets = walletsStore.wallets
    guard !wallets.isEmpty else { return [:] }
    let state = calculateState(wallets: wallets)
    return state
  }
  
  private func setupObservers() {
    balanceStore.addObserver(self) { observer, event in
      observer.didGetBalanceStoreEvent(event)
    }
    tonRatesStore.addObserver(self) { observer, event in
      observer.didGetTonRateStoreEvent(event)
    }
    stakingPoolsStore.addObserver(self) { observer, event in
      observer.didGetStakingPoolsStoreEvent(event)
    }
  }
  
  private func didGetBalanceStoreEvent(_ event: BalanceStore.Event) {
    switch event {
    case .didUpdateBalanceState(let wallet):
      updateState(wallets: [wallet])
    }
  }
  
  private func didGetTonRateStoreEvent(_ event: TonRatesStore.Event) {
    switch event {
    case .didUpdateTonRates:
      let wallets = walletsStore.wallets
      updateState(wallets: wallets)
    }
    
  }
  
  private func didGetStakingPoolsStoreEvent(_ event: StakingPoolsStore.Event) {
    switch event {
    case .didUpdateStakingPools(let wallet):
      updateState(wallets: [wallet])
    }
  }
  
  private func updateState(wallets: [Wallet]) {
    updateState { [weak self] state in
      guard let self else { return nil }
      let walletsState = self.calculateState(wallets: wallets)
      let updatedState = state.merging(walletsState, uniquingKeysWith: { $1 })
      return StateUpdate(newState: updatedState)
    } completion: { [weak self] _ in
      wallets.forEach { self?.sendEvent(.didUpdateProccessedBalance(wallet: $0)) }
    }
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
      let stakingPools = stakingPoolsStore.state[wallet] ?? []
      state[wallet] = calculateState(
        wallet: wallet,
        balanceState: walletBalanceState,
        tonRates: rates,
        stakingPools: stakingPools,
        currency: currency
      )
    }
    return state
  }
  
  private func calculateState(wallet: Wallet,
                              balanceState: WalletBalanceState?,
                              tonRates: Rates.Rate?,
                              stakingPools: [StackingPoolInfo],
                              currency: Currency) -> ProcessedBalanceState? {
    guard let balanceState = balanceState else {
      return nil
    }
    let walletBalance = balanceState.walletBalance
    
    let tonItem = processTonBalance(
      tonBalance: walletBalance.balance.tonBalance,
      tonRates: tonRates,
      currency: currency
    )
    
    let jettonsBalance = walletBalance.balance.jettonsBalance
    var stackingBalance = walletBalance.stacking
    
    var stakingItems = [ProcessedBalanceStakingItem]()
    var jettonItems = [ProcessedBalanceJettonItem]()
    
    for jetton in jettonsBalance {
      if StakingJettonMasterAddress.addresses.contains(jetton.item.jettonInfo.address),
         let pool = stakingPools.first(where: { $0.liquidJettonMaster == jetton.item.jettonInfo.address }) {
        
        let jettonStakingInfo = walletBalance.stacking.first(where: { $0.pool == pool.address })
        stackingBalance = stackingBalance.filter { $0 != jettonStakingInfo }
        
        let amount: Int64 = {
          if let tonRate = jetton.rates[.TON] {
            let converted = RateConverter().convertToDecimal(
              amount: jetton.quantity,
              amountFractionLength: jetton.item.jettonInfo.fractionDigits,
              rate: tonRate
            )
            let convertedFractionLength = min(Int16(TonInfo.fractionDigits),max(Int16(-converted.exponent), 0))
            return Int64(NSDecimalNumber(decimal: converted)
              .multiplying(byPowerOf10: convertedFractionLength).doubleValue)
          } else {
            return 0
          }
        }()
        
        let stakingInfo = AccountStackingInfo(
          pool: pool.address,
          amount: amount,
          pendingDeposit: jettonStakingInfo?.pendingDeposit ?? 0,
          pendingWithdraw: jettonStakingInfo?.pendingWithdraw ?? 0,
          readyWithdraw: jettonStakingInfo?.pendingWithdraw ?? 0
        )
        
        let jettonItem = processJettonBalance(jetton, currency: currency)
        
        let stakingItem = processStaking(
          stakingInfo,
          stakingPool: pool,
          jetton: jettonItem,
          tonRates: tonRates,
          currency: currency
        )
        
        stakingItems.append(stakingItem)
      } else {
        jettonItems.append(processJettonBalance(jetton, currency: currency))
      }
    }
    
    stakingItems.append(contentsOf: stackingBalance.map { item in
      let stackingPool = stakingPools.first(where: { $0.address == item.pool })
      return processStaking(item,
                            stakingPool: stackingPool,
                            jetton: nil,
                            tonRates: tonRates,
                            currency: currency)
    })
    
    let items: [ProcessedBalanceItem] = [.ton(tonItem)] + stakingItems.map { .staking($0) } + jettonItems.map { .jetton($0) }
    
    let processedBalance = ProcessedBalance(
      items: items,
      tonItem: tonItem,
      jettonItems: jettonItems,
      stakingItems: stakingItems,
      currency: currency,
      date: walletBalance.date
    )
    
    switch balanceState {
    case .current:
      return ProcessedBalanceState.current(processedBalance)
    case .previous:
      return ProcessedBalanceState.previous(processedBalance)
    }
  }
  
  private func processTonBalance(tonBalance: TonBalance,
                                 tonRates: Rates.Rate?,
                                 currency: Currency) -> ProcessedBalanceTonItem {
    let converted: Decimal
    let price: Decimal
    let diff: String?
    if let tonRate = tonRates {
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

    let tonItem = ProcessedBalanceTonItem(
      id: TonInfo.symbol,
      title: TonInfo.symbol,
      amount: UInt64(tonBalance.amount),
      fractionalDigits: TonInfo.fractionDigits,
      currency: currency,
      converted: converted,
      price: price,
      diff: diff
    )
    
    return tonItem
  }
  
  private func processJettonBalance(_ jettonBalance: JettonBalance,
                                    currency: Currency) -> ProcessedBalanceJettonItem {
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

    return ProcessedBalanceJettonItem(
      id: jettonBalance.item.jettonInfo.address.toRaw(),
      jetton: jettonBalance.item,
      amount: jettonBalance.quantity,
      fractionalDigits: jettonBalance.item.jettonInfo.fractionDigits,
      tag: nil,
      currency: currency,
      converted: converted,
      price: price,
      diff: diff
    )
  }
  
  private func processStaking(_ stakingInfo: AccountStackingInfo,
                              stakingPool: StackingPoolInfo?,
                              jetton: ProcessedBalanceJettonItem?,
                              tonRates: Rates.Rate?,
                              currency: Currency) -> ProcessedBalanceStakingItem {
    var amountConverted: Decimal = 0
    var pendingDepositConverted: Decimal = 0
    var pendingWithdrawConverted: Decimal = 0
    var readyWithdrawConverted: Decimal = 0
    var price: Decimal = 0
    if let tonRate = tonRates {
      amountConverted = RateConverter().convertToDecimal(
        amount: BigUInt(stakingInfo.amount),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      pendingDepositConverted = RateConverter().convertToDecimal(
        amount: BigUInt(stakingInfo.pendingDeposit),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      pendingWithdrawConverted = RateConverter().convertToDecimal(
        amount: BigUInt(stakingInfo.pendingWithdraw),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      readyWithdrawConverted = RateConverter().convertToDecimal(
        amount: BigUInt(stakingInfo.readyWithdraw),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      
      price = tonRate.rate
    }
    
    return ProcessedBalanceStakingItem(
      id: stakingInfo.pool.toRaw(),
      info: stakingInfo,
      poolInfo: stakingPool,
      jetton: jetton,
      currency: currency,
      amountConverted: amountConverted,
      pendingDepositConverted: pendingDepositConverted,
      pendingWithdrawConverted: pendingWithdrawConverted,
      readyWithdrawConverted: readyWithdrawConverted,
      price: price
    )
  }
}

private enum StakingJettonMasterAddress {
  static var addresses: [Address] {
    [
      // Tonstakers
      try! Address.parse("0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000")
    ]
  }
}
