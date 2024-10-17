import Foundation
import KeeperCore
import BigInt
import TonSwift
import TKCore
import TKLocalize

final class WalletBalanceBalanceModel {
  struct Item {
    let balanceItem: ProcessedBalanceItem
    let isPinned: Bool
    
    init(balanceItem: ProcessedBalanceItem, 
         isPinned: Bool = false) {
      self.balanceItem = balanceItem
      self.isPinned = isPinned
    }
  }
  
  struct BalanceListItems {
    let wallet: Wallet
    let items: [Item]
    let canManage: Bool
    let isSecure: Bool
  }
  
  var didUpdateItems: ((BalanceListItems) -> Void)?
  
  private let actor = SerialActor<Void>()
  
  private let walletsStore: WalletsStore
  private let balanceStore: ManagedBalanceStore
  private let stackingPoolsStore: StakingPoolsStore
  private let appSettingsStore: AppSettingsV3Store
  
  init(walletsStore: WalletsStore,
       balanceStore: ManagedBalanceStore,
       stackingPoolsStore: StakingPoolsStore,
       appSettingsStore: AppSettingsV3Store) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.stackingPoolsStore = stackingPoolsStore
    self.appSettingsStore = appSettingsStore
    
    walletsStore.addObserver(self) { observer, event in
      observer.didGetWalletsStoreEvent(event)
    }
    
    balanceStore.addObserver(self) { observer, event in
      observer.didGetBalanceStoreEvent(event)
    }
    
    stackingPoolsStore.addObserver(self) { observer, event in
      observer.didGetStackingPoolsStoreEvent(event)
    }
    
    appSettingsStore.addObserver(self) { observer, event in
      observer.didGetAppSettingsStoreEvent(event)
    }
  }
  
  func getItems() throws -> BalanceListItems {
    let activeWallet = try walletsStore.getActiveWallet()
    let isSecureMode = appSettingsStore.getState().isSecureMode
    let balanceState = balanceStore.getState()[activeWallet]
    let stakingPools = stackingPoolsStore.getState()[activeWallet]
    return createItems(
      wallet: activeWallet,
      balanceState: balanceState,
      stakingPools: stakingPools ?? [],
      isSecureMode: isSecureMode
    )
  }
  
  func getItems() async throws -> BalanceListItems {
    let activeWallet = try await walletsStore.getActiveWallet()
    let isSecureMode = await appSettingsStore.getState().isSecureMode
    let balanceState = await balanceStore.getState()[activeWallet]
    let stakingPools = await stackingPoolsStore.getState()[activeWallet]
    return createItems(
      wallet: activeWallet,
      balanceState: balanceState,
      stakingPools: stakingPools ?? [],
      isSecureMode: isSecureMode
    )
  }
  
  private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
    Task {
      switch event {
      case .didChangeActiveWallet:
        await self.actor.addTask(block: { await self.updateItems() })
      default: break
      }
    }
  }
  
  private func didGetBalanceStoreEvent(_ event: ManagedBalanceStore.Event) {
    Task {
      switch event {
      case .didUpdateManagedBalance(_, let wallet):
        switch await walletsStore.getState() {
        case .empty: break
        case .wallets(let state):
          guard state.activeWalelt == wallet else { return }
          await self.actor.addTask(block: { await self.updateItems() })
        }
      }
    }
  }
  
  private func didGetStackingPoolsStoreEvent(_ event: StakingPoolsStore.Event) {
    Task {
      switch event {
      case .didUpdateStakingPools(_, let wallet):
        switch await walletsStore.getState() {
        case .empty: break
        case .wallets(let state):
          guard state.activeWalelt == wallet else { return }
          await self.actor.addTask(block: { await self.updateItems() })
        }
      }
    }
  }
  
  private func didGetAppSettingsStoreEvent(_ event: AppSettingsV3Store.Event) {
    Task {
      await self.actor.addTask(block: { await self.updateItems() })
    }
  }
  
  private func updateItems() async {
    let walletsStoreState = await walletsStore.getState()
    switch walletsStoreState {
    case .empty: break
    case .wallets(let walletsState):
      let isSecureMode = await appSettingsStore.getState().isSecureMode
      let balanceState = await balanceStore.getState()[walletsState.activeWalelt]
      let stakingPools = await stackingPoolsStore.getState()[walletsState.activeWalelt]
      let items = createItems(
        wallet: walletsState.activeWalelt,
        balanceState: balanceState,
        stakingPools: stakingPools ?? [],
        isSecureMode: isSecureMode
      )
      didUpdateItems?(items)
    }
  }
  
  private func createItems(wallet: Wallet,
                           balanceState: ManagedBalanceState?,
                           stakingPools: [StackingPoolInfo],
                           isSecureMode: Bool) -> BalanceListItems {
    guard let balance = balanceState?.balance else {
      return BalanceListItems(wallet: wallet, items: [], canManage: false, isSecure: isSecureMode)
    }
    
    let items = balance.tonItems.map { Item(balanceItem: .ton($0), isPinned: false) }
    + balance.pinnedItems.map { Item(balanceItem: $0, isPinned: true) }
    + balance.unpinnedItems.map { Item(balanceItem: $0, isPinned: false) }

    let balanceListItems = BalanceListItems(
      wallet: wallet,
      items: items,
      canManage: balance.isManagable,
      isSecure: isSecureMode
    )
    return balanceListItems
  }
}
