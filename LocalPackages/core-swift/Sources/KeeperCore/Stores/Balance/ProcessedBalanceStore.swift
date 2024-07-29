import Foundation
import TonSwift
import BigInt

public enum ProcessedBalanceState: Equatable {
  case none
  case current(ProcessedBalance)
  case previous(ProcessedBalance)
  
  public var balance: ProcessedBalance? {
    switch self {
    case .none:
      return nil
    case .current(let balance):
      return balance
    case .previous(let balance):
      return balance
    }
  }
}

public final class ProcessedBalanceStore: StoreUpdated<[FriendlyAddress: ProcessedBalanceState]> {
  private let walletsStore: WalletsStore
  private let balanceStore: BalanceStoreV2
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let stakingPoolsStore: StakingPoolsStore
  
  init(walletsStore: WalletsStore,
       balanceStore: BalanceStoreV2,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       stakingPoolsStore: StakingPoolsStore) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.stakingPoolsStore = stakingPoolsStore
    super.init(state: [:])
    setupObservations()
  }
  
  public override func getInitialState() -> [FriendlyAddress : ProcessedBalanceState] {
    let wallets = walletsStore.getState().wallets
    let balanceStates = balanceStore.getState()
    let tonRates = tonRatesStore.getState()
    let currency = currencyStore.getCurrency()
    let stakingPools = stakingPoolsStore.getState()
    
    var states = [FriendlyAddress: ProcessedBalanceState]()
    let addresses = wallets.compactMap { try? $0.friendlyAddress }
    for address in addresses {
      states[address] = calculateState(
        address: address,
        balanceStates: balanceStates,
        tonRates: tonRates,
        currency: currency,
        stakingPools: stakingPools
      )
    }
    return states
  }
  
  private func setupObservations() {
    balanceStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
        observer.didUpdateBalanceStates(newState: newState, oldState: oldState)
      }
    
    tonRatesStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
        observer.didUpdateTonRates(newState: newState, oldState: oldState)
    }
    
    stakingPoolsStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
      observer.didUpdateStakingPools(newState: newState, oldState: oldState)
    }
  }
  
  private func didUpdateBalanceStates(newState: [FriendlyAddress: WalletBalanceState],
                                      oldState: [FriendlyAddress: WalletBalanceState]) {
    updateState { state in
      var updatedState = state
     
      let wallets = self.walletsStore.getState().wallets
      let tonRates = self.tonRatesStore.getState()
      let currency = self.currencyStore.getCurrency()
      let stakingPools = self.stakingPoolsStore.getState()
      let addresses = wallets.compactMap { try? $0.friendlyAddress }
      for address in addresses {
        guard newState[address] != oldState[address] else { continue }
        updatedState[address] = self.calculateState(
          address: address,
          balanceStates: newState,
          tonRates: tonRates,
          currency: currency,
          stakingPools: stakingPools
        )
      }
      
      return StateUpdate(newState: updatedState)
    }
  }
  
  private func didUpdateTonRates(newState: [Rates.Rate], 
                                 oldState: [Rates.Rate]) {
    updateState { state -> StateUpdate? in
      var updatedState = state
      
      let currency = self.currencyStore.getCurrency()
      guard newState.first(where: { $0.currency == currency }) != oldState.first(where: { $0.currency == currency }) else {
        return nil
      }
     
      let balanceStates = self.balanceStore.getState()
      let wallets = self.walletsStore.getState().wallets
      let stakingPools = self.stakingPoolsStore.getState()
      let addresses = wallets.compactMap { try? $0.friendlyAddress }
      for address in addresses {
        updatedState[address] = self.calculateState(
          address: address,
          balanceStates: balanceStates,
          tonRates: newState,
          currency: currency,
          stakingPools: stakingPools
        )
      }
      
      return StateUpdate(newState: updatedState)
    }
  }
  
  private func didUpdateStakingPools(newState: [FriendlyAddress: [StackingPoolInfo]],
                                     oldState: [FriendlyAddress: [StackingPoolInfo]]) {
    updateState { state -> StateUpdate? in
      var updatedState = state
     
      let wallets = self.walletsStore.getState().wallets
      let balanceStates = self.balanceStore.getState()
      let tonRates = self.tonRatesStore.getState()
      let currency = self.currencyStore.getCurrency()
      let addresses = wallets.compactMap { try? $0.friendlyAddress }
      for address in addresses {
        guard newState[address] != oldState[address] else { continue }
        updatedState[address] = self.calculateState(
          address: address,
          balanceStates: balanceStates,
          tonRates: tonRates,
          currency: currency,
          stakingPools: newState
        )
      }
      
      return StateUpdate(newState: updatedState)
    }
  }
  
  private func calculateState(address: FriendlyAddress,
                              balanceStates: [FriendlyAddress: WalletBalanceState],
                              tonRates: [Rates.Rate],
                              currency: Currency,
                              stakingPools: [FriendlyAddress: [StackingPoolInfo]]) -> ProcessedBalanceState {
    guard let walletBalanceState = balanceStates[address] else {
      return ProcessedBalanceState.none
    }
    let walletStakingPools = stakingPools[address] ?? []
    
    let walletBalance = walletBalanceState.walletBalance
    
    let tonItem = processTonBalance(
      tonBalance: walletBalance.balance.tonBalance,
      tonRates: tonRates,
      currency: currency
    )
    
    var jettonsBalance = walletBalance.balance.jettonsBalance
    var stackingBalance = walletBalance.stacking
    
    var stakingItems = [ProcessedBalanceStakingItem]()
    var jettonItems = [ProcessedBalanceJettonItem]()
    
    for jetton in jettonsBalance {
      if StakingJettonMasterAddress.addresses.contains(jetton.item.jettonInfo.address),
         let pool = walletStakingPools.first(where: { $0.liquidJettonMaster == jetton.item.jettonInfo.address }) {
        
        var jettonStakingInfo = walletBalance.stacking.first(where: { $0.pool == pool.address })
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
      let stackingPool = walletStakingPools.first(where: { $0.address == item.pool })
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
    
    switch walletBalanceState {
    case .current:
      return ProcessedBalanceState.current(processedBalance)
    case .previous:
      return ProcessedBalanceState.previous(processedBalance)
    }
  }
  
  private func processTonBalance(tonBalance: TonBalance,
                                 tonRates: [Rates.Rate],
                                 currency: Currency) -> ProcessedBalanceTonItem {
    let converted: Decimal
    let price: Decimal
    let diff: String?
    if let tonRate = tonRates.first(where: { $0.currency == currency }) {
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
                              tonRates: [Rates.Rate],
                              currency: Currency) -> ProcessedBalanceStakingItem {
    var amountConverted: Decimal = 0
    var pendingDepositConverted: Decimal = 0
    var pendingWithdrawConverted: Decimal = 0
    var readyWithdrawConverted: Decimal = 0
    var price: Decimal = 0
    if let tonRate = tonRates.first(where: { $0.currency == currency }) {
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

