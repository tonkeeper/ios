import Foundation
import KeeperCore
import BigInt
import TonSwift
import TKCore
import TKLocalize

final class WalletBalanceBalanceModel {
  struct BalanceListItems {
    let items: [BalanceItem]
    let canManage: Bool
  }

  private let actor = SerialActor<Void>()

  var didUpdateItems: ((BalanceListItems, _ isSecure: Bool) -> Void)? {
    didSet {
      let activeWallet = self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      let balance = self.convertedBalanceStore.getState()[address]?.balance
      let isSecure = self.secureMode.getState()
      let stackingPools = self.stackingPoolsStore.getState()[address] ?? []
      let tokenManagementState = self.tokenManagementStore.getState()
      self.update(balance: balance,
                  stackingPools: stackingPools,
                  isSecure: isSecure,
                  tokenManagementState: tokenManagementState)
    }
  }
  
  private var tokenManagementStore: TokenManagementStore
  
  private let walletsStore: WalletsStoreV2
  private let convertedBalanceStore: ConvertedBalanceStoreV2
  private let stackingPoolsStore: StakingPoolsStore
  private let tokenManagementStoreProvider: (Wallet) -> TokenManagementStore
  private let secureMode: SecureMode
  
  init(walletsStore: WalletsStoreV2,
       convertedBalanceStore: ConvertedBalanceStoreV2,
       stackingPoolsStore: StakingPoolsStore,
       tokenManagementStoreProvider: @escaping (Wallet) -> TokenManagementStore,
       secureMode: SecureMode) {
    self.walletsStore = walletsStore
    self.convertedBalanceStore = convertedBalanceStore
    self.stackingPoolsStore = stackingPoolsStore
    self.tokenManagementStoreProvider = tokenManagementStoreProvider
    self.secureMode = secureMode
    self.tokenManagementStore = tokenManagementStoreProvider(walletsStore.getState().activeWallet)
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newWalletsState, oldWalletsState in
      Task {
        await observer.didUpdateWalletsState(newWalletsState: newWalletsState, oldWalletsState: oldWalletsState)
      }
    }
    convertedBalanceStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      Task {
        await observer.didUpdateBalances(newState, oldState)
      }
    }
    secureMode.addObserver(self, notifyOnAdded: false) { observer, newState, _ in
      Task {
        await observer.didUpdateSecureMode(newState)
      }
    }
    tokenManagementStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      Task {
        await observer.didUpdateTokenManagementState(_: newState, oldState: oldState)
      }
    }
  }
  
  private func didUpdateWalletsState(newWalletsState: WalletsState,
                                     oldWalletsState: WalletsState?) async {
    await actor.addTask(block: {
      guard newWalletsState.activeWallet != oldWalletsState?.activeWallet else { return }
      guard let address = try? newWalletsState.activeWallet.friendlyAddress else { return }
      self.tokenManagementStore = self.tokenManagementStoreProvider(newWalletsState.activeWallet)
      self.tokenManagementStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
        Task {
          await observer.didUpdateTokenManagementState(_: newState, oldState: oldState)
        }
      }
      let balance = await self.convertedBalanceStore.getState()[address]?.balance
      let isSecure = await self.secureMode.isSecure
      let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
      let tokenManagementState = await self.tokenManagementStore.getState()
      self.update(balance: balance,
                  stackingPools: stackingPools,
                  isSecure: isSecure,
      tokenManagementState: tokenManagementState)
    })
  }
  
  private func didUpdateBalances(_ newBalances: [FriendlyAddress: ConvertedBalanceState],
                                 _ oldBalances: [FriendlyAddress: ConvertedBalanceState]?) async {
    await actor.addTask(block: {
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      guard newBalances[address] != oldBalances?[address] else { return }
      let isSecure = await self.secureMode.isSecure
      let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
      let tokenManagementState = await self.tokenManagementStore.getState()
      self.update(balance: newBalances[address]?.balance,
                  stackingPools: stackingPools,
                  isSecure: isSecure, 
                  tokenManagementState: tokenManagementState)
    })
  }
  
  private func didUpdateSecureMode(_ isSecure: Bool) async {
    await actor.addTask(block: {
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      let balance = await self.convertedBalanceStore.getState()[address]?.balance
      let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
      let tokenManagementState = await self.tokenManagementStore.getState()
      self.update(balance: balance,
                  stackingPools: stackingPools,
                  isSecure: isSecure,
                  tokenManagementState: tokenManagementState)
    })
  }
  
  private func didUpdateTokenManagementState(_ state: TokenManagementState, oldState: TokenManagementState?) async {
    await actor.addTask(block: {
      guard state != oldState else { return }
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      let balance = await self.convertedBalanceStore.getState()[address]?.balance
      let isSecure = await self.secureMode.isSecure
      let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
      self.update(
        balance: balance,
        stackingPools: stackingPools,
        isSecure: isSecure,
        tokenManagementState: state
      )
    })
  }
  
  private func update(balance: ConvertedBalance?,
                      stackingPools: [StackingPoolInfo],
                      isSecure: Bool,
                      tokenManagementState: TokenManagementState) {
    guard let balance else {
      didUpdateItems?(
        BalanceListItems(items: [],
                         canManage: false),
        isSecure
      )
      return
    }
    
    let balanceItems = BalanceItems(
      balance: balance,
      stackingPools: stackingPools
    )
    
    var pinnedItems = [BalanceItem]()
    var unpinnedItems = [BalanceItem]()
    
    for item in balanceItems.items {
      if tokenManagementState.pinnedItems.contains(item.identifier) {
        pinnedItems.append(item)
      } else {
        guard !tokenManagementState.hiddenItems.contains(item.identifier) else {
          continue
        }
        unpinnedItems.append(item)
      }
    }
    
    let sortedPinnedItems = pinnedItems.sorted {
      guard let lIndex = tokenManagementState.pinnedItems.firstIndex(of: $0.identifier) else {
        return false
      }
      guard let rIndex = tokenManagementState.pinnedItems.firstIndex(of: $1.identifier) else {
        return true
      }
      
      return lIndex < rIndex
    }
    
    let sortedUnpinnedItems = unpinnedItems.sorted {
      switch ($0, $1) {
      case (.ton, _):
        return true
      case (_, .ton):
        return false
      case (.staking(let lModel), .staking(let rModel)):
        return lModel.converted > rModel.converted
      case (.staking, _):
        return true
      case (_, .staking):
        return false
      case (.jetton(let lModel), .jetton(let rModel)):
        switch (lModel.jetton.jettonInfo.verification, rModel.jetton.jettonInfo.verification) {
        case (.whitelist, .whitelist):
          return lModel.converted > rModel.converted
        case (.whitelist, _):
          return true
        case (_, .whitelist):
          return false
        default:
          return lModel.converted > rModel.converted
        }
      }
    }
    
    let items = BalanceListItems(
      items: sortedPinnedItems + sortedUnpinnedItems,
      canManage: balanceItems.items.count > 2
    )
    didUpdateItems?(items, isSecure)
  }
}
