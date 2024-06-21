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

  private let balanceStore: WalletsBalanceStoreV2
  private let currencyStore: CurrencyStoreV2
  private let walletsStore: WalletsStoreV2
  private let balanceService: BalanceService
  
  init(balanceStore: WalletsBalanceStoreV2, 
       currencyStore: CurrencyStoreV2,
       walletsStore: WalletsStoreV2,
       balanceService: BalanceService) {
    self.balanceStore = balanceStore
    self.currencyStore = currencyStore
    self.walletsStore = walletsStore
    self.balanceService = balanceService
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState in
      Task { await observer.didUpdateWalletsState(walletsState) }
    }
    currencyStore.addObserver(self, notifyOnAdded: true) { observer, currency in
      Task { await observer.didUpdateCurrency(currency) }
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
        let balance = try await balanceService.loadWalletBalance(wallet: wallet, currency: currency)
        guard !Task.isCancelled else { return }
        await balanceStore.setBalanceState(.current(balance), wallet: wallet)
      } catch {
        guard !error.isCancelledError else { return }
        guard let balanceState = await balanceStore.getBalanceState(wallet: wallet) else { return }
        await balanceStore.setBalanceState(.previous(balanceState.walletBalance), wallet: wallet)
      }
    }
    tasksInProgress[address] = task
  }
}
