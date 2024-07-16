import Foundation
import TonSwift

actor WalletBalanceLoaderV2 {
  struct State: Equatable {
    let walletsState: WalletsState?
    let currency: Currency?
  }
  
  private var tasksInProgress = [FriendlyAddress: Task<(), Never>]()
  private var state = State(walletsState: nil, currency: nil) {
    didSet {
      guard state != oldValue else { return }
      Task {
        await reloadBalance(state: state, oldState: oldValue)
      }
    }
  }

  private let balanceStore: BalanceStoreV2
  private let currencyStore: CurrencyStoreV2
  private let walletsStore: WalletsStoreV2
  private let stakingPoolsStore: StakingPoolsStore
  private let balanceService: BalanceService
  private let stackingService: StakingService
  
  init(balanceStore: BalanceStoreV2, 
       currencyStore: CurrencyStoreV2,
       walletsStore: WalletsStoreV2,
       stakingPoolsStore: StakingPoolsStore,
       balanceService: BalanceService,
       stackingService: StakingService) {
    self.balanceStore = balanceStore
    self.currencyStore = currencyStore
    self.stakingPoolsStore = stakingPoolsStore
    self.walletsStore = walletsStore
    self.balanceService = balanceService
    self.stackingService = stackingService
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState, _ in
      Task { await observer.didUpdateWalletsState(walletsState) }
    }
    currencyStore.addObserver(self, notifyOnAdded: true) { observer, currency, _ in
      Task { await observer.didUpdateCurrency(currency) }
    }
  }
  
  nonisolated
  func reloadBalance() {
    Task {
      let state = await state
      guard let currency = state.currency,
            let wallets = state.walletsState?.wallets else {
        return
      }
      await self.reloadBalance(wallets: wallets, currency: currency)
    }
  }
  
  nonisolated
  func reloadBalance(address: FriendlyAddress) {
    Task {
      guard let wallet = await walletsStore.getState().wallets.first(where: { (try? address == $0.friendlyAddress) == true }) else {
        return
      }
      let currency = await currencyStore.getState()
      await reloadBalance(wallet: wallet, currency: currency)
    }
  }
}

private extension WalletBalanceLoaderV2 {
  func didUpdateWalletsState(_ walletsState: WalletsState) {
    let newState = State(walletsState: walletsState, currency: state.currency)
    self.state = newState
  }
  
  func didUpdateCurrency(_ currency: Currency) {
    let newState = State(walletsState: state.walletsState, currency: currency)
    self.state = newState
  }
  
  func reloadBalance(state: State, oldState: State) async {
    guard let currency = state.currency,
          let wallets = state.walletsState?.wallets,
          let activeWallet = state.walletsState?.activeWallet else { return }
    if state.currency != oldState.currency {
      await reloadBalance(wallets: wallets, currency: currency)
      return
    }
    if wallets != oldState.walletsState?.wallets {
      let oldWallets = oldState.walletsState?.wallets ?? []
      let walletsDiff = Set(wallets).symmetricDifference(Set(oldWallets))
      await reloadBalance(wallets: Array(walletsDiff), currency: currency)
    }
    if activeWallet != oldState.walletsState?.activeWallet {
      reloadBalance(wallet: activeWallet, currency: currency)
    }
  }
  
  func reloadBalance(wallets: [Wallet], currency: Currency) async {
    guard !wallets.isEmpty else { return }
    await withTaskGroup(of: Void.self) { [weak self] taskGroup in
      guard let self else { return }
      for wallet in wallets {
        taskGroup.addTask {
          await self.reloadBalance(wallet: wallet, currency: currency)
        }
      }
    }
  }
  
  func reloadBalance(wallet: Wallet, currency: Currency) {
    guard let address = try? wallet.friendlyAddress else { return }
    if let task = tasksInProgress[address] {
      task.cancel()
      tasksInProgress[address] = nil
    }
    let task = Task {
      do {
        async let balanceTask = balanceService.loadWalletBalance(wallet: wallet, currency: currency)
        async let stakingPoolsTask = stackingService.loadStakingPools(wallet: wallet)
        
        let balance = try await balanceTask
        let pools: [StackingPoolInfo]
        do {
          pools = try await stakingPoolsTask
        } catch {
          pools = []
        }
        
        guard !Task.isCancelled else { return }
        await stakingPoolsStore.setStackingPools(pools: pools, address: address)
        await balanceStore.setBalanceState(.current(balance), address: address)
      } catch {
        guard !error.isCancelledError else { return }
        guard let balanceState = await balanceStore.getBalanceState(address: address) else { return }
        await balanceStore.setBalanceState(.previous(balanceState.walletBalance), address: address)
      }
    }
    tasksInProgress[address] = task
  }
}
