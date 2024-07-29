import Foundation
import TonSwift
import BigInt

public struct BalanceState: Equatable {
  public let balanceState: WalletBalanceState
  public let tonRates: [Rates.Rate]
  public let stakingPools: [StackingPoolInfo]
  public let currency: Currency
}

public final class BalanceStateStore: StoreUpdated<[Wallet: BalanceState]> {
  private let walletsStore: WalletsStoreV2
  private let balanceStore: BalanceStoreV2
  private let tonRatesStore: TonRatesStoreV2
  private let currencyStore: CurrencyStoreV2
  private let stakingPoolsStore: StakingPoolsStore
  
  init(walletsStore: WalletsStoreV2, 
       balanceStore: BalanceStoreV2,
       tonRatesStore: TonRatesStoreV2,
       currencyStore: CurrencyStoreV2,
       stakingPoolsStore: StakingPoolsStore) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.stakingPoolsStore = stakingPoolsStore
    super.init(state: [:])
  }
  
  public func update(wallet: Wallet, 
                     balanceState: WalletBalanceState,
                     tonRates: [Rates.Rate],
                     stakingPools: [StackingPoolInfo],
                     currency: Currency,
                     completion: (() -> Void)?) {
    updateState { state in
      var updatedState = state
      let updatedWalletState = BalanceState(
        balanceState: balanceState,
        tonRates: tonRates,
        stakingPools: stakingPools,
        currency: currency
      )
      updatedState[wallet] = updatedWalletState
      return StateUpdate(newState: updatedState)
    } completion: {
      completion?()
    }
  }
  
  public func update(wallet: Wallet,
                     balanceState: WalletBalanceState,
                     tonRates: [Rates.Rate],
                     stakingPools: [StackingPoolInfo],
                     currency: Currency) async {
    await updateState { state in
      var updatedState = state
      let updatedWalletState = BalanceState(
        balanceState: balanceState,
        tonRates: tonRates,
        stakingPools: stakingPools,
        currency: currency
      )
      updatedState[wallet] = updatedWalletState
      return StateUpdate(newState: updatedState)
    }
  }
  
  public override func getInitialState() -> [Wallet : BalanceState] {
    let wallets = walletsStore.getState().wallets
    let balanceStates = balanceStore.getState()
    let tonRates = tonRatesStore.getState()
    let currency = currencyStore.getCurrency()
    let stakingPools = stakingPoolsStore.getState()
    
    var states = [Wallet: BalanceState]()
    for wallet in wallets {
      states[wallet] = calculateState(
        wallet: wallet,
        balanceState: balanceStates,
        tonRates: tonRates,
        currency: currency,
        stakingPools: stakingPools
      )
    }
    return states
  }
  
  private func calculateState(wallet: Wallet,
                              balanceState: [FriendlyAddress: WalletBalanceState],
                              tonRates: [Rates.Rate],
                              currency: Currency,
                              stakingPools: [FriendlyAddress: [StackingPoolInfo]]) -> BalanceState? {
    guard let address = try? wallet.friendlyAddress,
          let balanceState = balanceState[address] else { return nil }
    return BalanceState(
      balanceState: balanceState,
      tonRates: tonRates,
      stakingPools: stakingPools[address] ?? [],
      currency: currency
    )
  }
}
