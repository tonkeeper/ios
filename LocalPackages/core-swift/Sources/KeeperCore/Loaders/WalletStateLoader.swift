import Foundation
import TonSwift

public final class WalletStateLoader: StoreV3<WalletStateLoader.Event, WalletStateLoader.State> {
  public struct State {
    public var balanceLoadTasks: [Wallet: Task<(), Never>]
    public var nftLoadTasks: [Wallet: Task<(), Never>]
    public var reloadStateTask: Task<(), Never>?
    public var ratesLoadTask: Task<[Rates.Rate], Swift.Error>?
    
    init(balanceLoadTasks: [Wallet : Task<(), Never>] = [:],
         nftLoadTasks: [Wallet : Task<(), Never>] = [:],
         reloadStateTask: Task<(), Never>? = nil,
         ratesLoadTask: Task<[Rates.Rate], Error>? = nil) {
      self.balanceLoadTasks = balanceLoadTasks
      self.nftLoadTasks = nftLoadTasks
      self.reloadStateTask = reloadStateTask
      self.ratesLoadTask = ratesLoadTask
    }
  }
  
  public enum Event {
    case didStartLoadBalance(wallet: Wallet)
    case didEndLoadBalance(wallet: Wallet)
  }
  
  private let balanceStore: BalanceStoreV3
  private let currencyStore: CurrencyStoreV3
  private let walletsStore: WalletsStoreV3
  private let ratesStore: TonRatesStoreV3
  private let stakingPoolsStore: StakingPoolsStoreV3
  private let balanceService: BalanceService
  private let stackingService: StakingService
  private let accountNFTService: AccountNFTService
  private let ratesService: RatesService
  private let backgroundUpdateUpdater: BackgroundUpdateUpdater
  
  public init(balanceStore: BalanceStoreV3,
              currencyStore: CurrencyStoreV3,
              walletsStore: WalletsStoreV3,
              ratesStore: TonRatesStoreV3,
              stakingPoolsStore: StakingPoolsStoreV3,
              balanceService: BalanceService,
              stackingService: StakingService,
              accountNFTService: AccountNFTService,
              ratesService: RatesService,
              backgroundUpdateUpdater: BackgroundUpdateUpdater) {
    self.balanceStore = balanceStore
    self.currencyStore = currencyStore
    self.walletsStore = walletsStore
    self.ratesStore = ratesStore
    self.stakingPoolsStore = stakingPoolsStore
    self.balanceService = balanceService
    self.stackingService = stackingService
    self.accountNFTService = accountNFTService
    self.ratesService = ratesService
    self.backgroundUpdateUpdater = backgroundUpdateUpdater
    super.init(state: State())
    addObservers()
  }
  
  public override var initialState: State {
    State()
  }
  
  func startStateReload() {
    stopStateReload()
    
    let task = Task {
      let wallets = await walletsStore.getState()
      switch wallets {
      case .empty:
        return
      case .wallets(let wallets):
        let currency = await currencyStore.getState()
        await loadRatesAndStore(currency: currency)
        await loadBalance(wallets: wallets.wallets, currency: currency)
        try? await Task.sleep(nanoseconds: 60_000_000_000)
        guard !Task.isCancelled else { return }
        startStateReload()
      }
    }
    
    Task {
      await setReloadStateTask(task: nil)
      await setReloadStateTask(task: task)
    }
  }
  
  func stopStateReload() {
    Task {
      await setReloadStateTask(task: nil)
    }
  }
  
  func loadNFTs() {
    Task {
      switch await walletsStore.getState() {
      case .empty:
        break
      case .wallets(let wallets):
        await loadNFTs(wallet: wallets.activeWalelt)
      }
    }
  }
  
  private func addObservers() {
    self.walletsStore.addObserver(self) { observer, event in
      observer.didGetWalletsStoreEvent(event)
    }
    self.currencyStore.addObserver(self) { observer, event in
      observer.didGetCurrencyStoreEvent(event)
    }
  }
  
  private func didGetWalletsStoreEvent(_ event: WalletsStoreV3.Event) {
    Task {
      let currency = await currencyStore.getState()
      switch event {
      case .didAddWallets(let wallets):
        await loadBalance(wallets: wallets, currency: currency)
      case .didChangeActiveWallet(let wallet):
        await loadBalance(wallets: [wallet], currency: currency)
        loadNFTs()
      default: break
      }
    }
  }
  
  private func didGetCurrencyStoreEvent(_ event: CurrencyStoreV3.Event) {
    Task {
      let wallets = await walletsStore.getState()
      switch wallets {
      case .empty:
        return
      case .wallets(let wallets):
        let currency = await currencyStore.getState()
        await loadBalance(wallets: wallets.wallets, currency: currency)
      }
    }
  }
  
  private func loadBalance(wallets: [Wallet], currency: Currency) async {
    guard !wallets.isEmpty else { return }
    await withTaskGroup(of: Void.self) { [weak self] taskGroup in
      guard let self else { return }
      for wallet in wallets {
        taskGroup.addTask {
          await self.loadBalance(wallet: wallet, currency: currency)
        }
      }
    }
  }
  
  private func loadBalance(wallet: Wallet, currency: Currency) async {
    let task = Task {
      do {
        async let balanceTask = self.balanceService.loadWalletBalance(wallet: wallet, currency: currency)
        async let stakingPoolTask = self.stackingService.loadStakingPools(wallet: wallet)
        
        let balance = try await balanceTask
        let pools: [StackingPoolInfo]
        do {
          pools = try await stakingPoolTask
        } catch {
          pools = []
        }
        
        await balanceStore.setBalanceState(.current(balance), wallet: wallet)
        await stakingPoolsStore.setStackingPools(pools, wallet: wallet)
      } catch {
        guard error.isCancelledError else { return }
        guard let balanceState = await self.balanceStore.getState()[wallet] else {
          return
        }
        await self.balanceStore.setBalanceState(.previous(balanceState.walletBalance), wallet: wallet)
      }
      await setBalanceLoadTask(task: nil, wallet: wallet)
    }
    
    await setBalanceLoadTask(task: task, wallet: wallet)
  }
  
  private func loadNFTs(wallet: Wallet) async {
    let task = Task {
      do {
        async let nftsTask = self.accountNFTService.loadAccountNFTs(
          wallet: wallet,
          collectionAddress: nil,
          limit: nil,
          offset: nil,
          isIndirectOwnership: true
        )

        let nfts = try await nftsTask
        
        // TODO: save to store
      } catch {
        guard error.isCancelledError else { return }
      }
      await setNFTLoadTask(task: nil, wallet: wallet)
    }
    await setNFTLoadTask(task: task, wallet: wallet)
  }
  
  private func loadRatesAndStore(currency: Currency) async {
    do {
      let rates = try await loadRates(currency: currency)
      await ratesStore.setRates(rates)
    } catch {
      guard !error.isCancelledError else { return }
      await ratesStore.setRates([])
    }
  }
  
  private func loadRates(currency: Currency) async throws -> [Rates.Rate] {
    let task = Task<[Rates.Rate], Swift.Error> {
      let rates = try await ratesService.loadRates(jettons: [], currencies: [currency, .TON]).ton
      try Task.checkCancellation()
      await setRatesLoadTask(task: nil)
      return rates
    }
    
    await setRatesLoadTask(task: task)
    
    return try await task.value
  }
  
  private func setBalanceLoadTask(task: Task<(), Never>?, wallet: Wallet) async {
    await setState { state in
      var updatedState = state
      if let stateTask = state.balanceLoadTasks[wallet] {
        stateTask.cancel()
        updatedState.balanceLoadTasks[wallet] = nil
      }

      updatedState.balanceLoadTasks[wallet] = task
      return StateUpdate(newState: updatedState)
    } notify: {
      if task != nil {
        self.sendEvent(.didStartLoadBalance(wallet: wallet))
      } else {
        self.sendEvent(.didEndLoadBalance(wallet: wallet))
      }
    }
  }
  
  private func setNFTLoadTask(task: Task<(), Never>?, wallet: Wallet) async {
    await setState { state in
      var updatedState = state
      if let stateTask = state.nftLoadTasks[wallet] {
        stateTask.cancel()
        updatedState.nftLoadTasks[wallet] = nil
      }

      updatedState.nftLoadTasks[wallet] = task
      return StateUpdate(newState: updatedState)
    }
  }
  
  private func setReloadStateTask(task: Task<(), Never>?) async {
    await setState { state in
      var updatedState = state
      if let stateTask = state.reloadStateTask {
        stateTask.cancel()
        updatedState.reloadStateTask = nil
      }
      
      updatedState.reloadStateTask = task
      return StateUpdate(newState: updatedState)
    }
  }
  
  private func setRatesLoadTask(task: Task<[Rates.Rate], Swift.Error>?) async {
    await setState { state in
      var updatedState = state
      if let stateTask = state.ratesLoadTask {
        stateTask.cancel()
        updatedState.ratesLoadTask = nil
      }
      updatedState.ratesLoadTask = task
      return StateUpdate(newState: updatedState)
    }
  }
}
