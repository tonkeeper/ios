import Foundation
import TonSwift

actor WalletStateLoader {
  
  private var reloadBalanceTaskInProgress = [Wallet: Task<(), Never>]()
  private var reloadStateTask: Task<(), Never>?
  private var loadRatesTask: Task<([Rates.Rate]), Never>?
  
  private let balanceStore: BalanceStoreV2
  private let currencyStore: CurrencyStoreV2
  private let walletsStore: WalletsStoreV2
  private let ratesStore: TonRatesStoreV2
  private let stakingPoolsStore: StakingPoolsStore
  private let balanceService: BalanceService
  private let stackingService: StakingService
  private let ratesService: RatesService
  private let backgroundUpdateUpdater: BackgroundUpdateUpdater
  
  init(balanceStore: BalanceStoreV2, 
       currencyStore: CurrencyStoreV2,
       walletsStore: WalletsStoreV2,
       ratesStore: TonRatesStoreV2,
       stakingPoolsStore: StakingPoolsStore,
       balanceService: BalanceService,
       stackingService: StakingService,
       ratesService: RatesService,
       backgroundUpdateUpdater: BackgroundUpdateUpdater) {
    self.balanceStore = balanceStore
    self.currencyStore = currencyStore
    self.walletsStore = walletsStore
    self.ratesStore = ratesStore
    self.stakingPoolsStore = stakingPoolsStore
    self.balanceService = balanceService
    self.stackingService = stackingService
    self.ratesService = ratesService
    self.backgroundUpdateUpdater = backgroundUpdateUpdater
    Task {
      await setupObserverations()
    }
  }
  
  nonisolated
  func startStateReload() {
    stopStateReload()
    let task = Task {
      let walletsState = await walletsStore.getState()
      let currency = await currencyStore.getCurrency()
      await reloadBalance(wallets: walletsState.wallets, currency: currency)
      try? await Task.sleep(nanoseconds: 15_000_000_000)
      guard !Task.isCancelled else { return }
      startStateReload()
    }
    Task {
      await setReloadStateTask(task)
    }
  }
  
  nonisolated
  func stopStateReload() {
    Task {
      await resetReloadStateTask()
    }
  }
}

private extension WalletStateLoader {
  func setReloadStateTask(_ task: Task<(), Never>) {
    self.reloadStateTask = task
  }
  
  func resetReloadStateTask() {
    self.reloadStateTask?.cancel()
    self.reloadStateTask = nil
  }
  
  func setupObserverations() {
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      Task {
        await observer.didUpdateWalletsStoreState(newState: newState, oldState: oldState)
      }
    }
    
    currencyStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      Task {
        await observer.didUpdateCurrencyStoreState(newState: newState, oldState: oldState)
      }
    }
  }
  
  func didUpdateWalletsStoreState(newState: WalletsState, oldState: WalletsState) async {
    var walletsToUpdate = newState.wallets
      .filter { !oldState.wallets.contains($0) }
    if newState.activeWallet != oldState.activeWallet {
      walletsToUpdate.append(newState.activeWallet)
    }
    let currency = await currencyStore.getCurrency()
    await reloadBalance(wallets: walletsToUpdate, currency: currency)
  }
  
  func didUpdateCurrencyStoreState(newState: Currency, oldState: Currency) async {
    guard newState != oldState else { return }
    let walletState = await walletsStore.getState()
    await reloadBalance(wallets: walletState.wallets, currency: newState)
  }
  
  func reloadBalance(wallets: [Wallet], currency: Currency) async {
    guard !wallets.isEmpty else { return }
    let rates = await loadRates(currency: currency)
    await ratesStore.setTonRates(rates)
    await withTaskGroup(of: Void.self) { [weak self] taskGroup in
      guard let self else { return }
      for wallet in wallets {
        taskGroup.addTask {
          await self.reloadBalance(wallet: wallet, currency: currency, rates: rates)
        }
      }
    }
  }
  
  func reloadBalance(wallet: Wallet, currency: Currency, rates: [Rates.Rate]) {
    guard let friendlyAddress = try? wallet.friendlyAddress else { return }
    if let task = reloadBalanceTaskInProgress[wallet] {
      task.cancel()
      reloadBalanceTaskInProgress[wallet] = nil
    }
    
    let task = Task {
      do {
        async let balanceTask = balanceService.loadWalletBalance(
          wallet: wallet,
          currency: currency
        )
        async let stakingPoolsTask = stackingService.loadStakingPools(wallet: wallet)
        
        let balance = try await balanceTask
        let pools = (try? await stakingPoolsTask) ?? []
        guard !Task.isCancelled else { return }
        
        await stakingPoolsStore.setStackingPools(pools: pools,
                                                 address: friendlyAddress)
        await balanceStore.setBalanceState(.current(balance),
                                           address: friendlyAddress)
      } catch {
        guard error.isCancelledError else { return }
        guard let balanceState = await self.balanceStore.getState()[friendlyAddress] else {
          return
        }
        await balanceStore.updateState { state in
          var updatedState = state
          updatedState[friendlyAddress] = .previous(balanceState.walletBalance)
          return BalanceStoreV2.StateUpdate(newState: updatedState)
        }
      }
    }
    reloadBalanceTaskInProgress[wallet] = task
  }
  
  func loadRates(currency: Currency) async -> [Rates.Rate] {
    if let task = loadRatesTask {
      task.cancel()
      self.loadRatesTask = nil
    }
    
    let task = Task<[Rates.Rate], Never> {
      do {
        return try await ratesService.loadRates(jettons: [], currencies: [currency, .TON]).ton
      } catch {
        return []
      }
    }
    return await task.value
  }
}
