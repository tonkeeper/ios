import Foundation
import KeeperCore
import TKCore
import TonSwift

final class ManageTokensModel {
  
  struct UnpinnedItem {
    let item: BalanceItem
    let isHidden: Bool
  }
  
  struct State {
    let pinnedItems: [BalanceItem]
    let unpinnedItems: [UnpinnedItem]
  }
  
  var didUpdateState: ((State) -> Void)?
  
  private let actor = SerialActor<Void>()

  private let wallet: Wallet
  private let convertedBalanceStore: ConvertedBalanceStore
  private let tokenManagementStore: TokenManagementStore
  private let stackingPoolsStore: StakingPoolsStore
  
  init(wallet: Wallet,
       tokenManagementStore: TokenManagementStore,
       convertedBalanceStore: ConvertedBalanceStore,
       stackingPoolsStore: StakingPoolsStore) {
    self.wallet = wallet
    self.tokenManagementStore = tokenManagementStore
    self.convertedBalanceStore = convertedBalanceStore
    self.stackingPoolsStore = stackingPoolsStore
    
    convertedBalanceStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      Task {
        await observer.didUpdateBalanceState(newState: newState, oldState: oldState)
      }
    }
    
    tokenManagementStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      Task {
        await observer.didUpdateTokenManagementState(newState: newState, oldState: oldState)
      }
    }
  }
  
  func getState() -> State {
    guard let address = try? wallet.friendlyAddress,
          let balance = convertedBalanceStore.getState()[address]?.balance else {
      return State(pinnedItems: [], unpinnedItems: [])
    }
    
    let tokenManagementState = tokenManagementStore.getState()
    let stackingPools = stackingPoolsStore.getState()[address] ?? []
    
    return createState(
      balance: balance,
      tokenManagementState: tokenManagementState,
      stackingPools: stackingPools
    )
  }
  
  func pinItem(identifier: String) async {
    await tokenManagementStore.pinItem(identifier: identifier)
  }
  
  func unpinItem(identifier: String) async {
    await tokenManagementStore.unpinItem(identifier: identifier)
  }
  
  func hideItem(identifier: String) async {
    await tokenManagementStore.hideItem(identifier: identifier)
  }
  
  func unhideItem(identifier: String) async {
    await tokenManagementStore.unhideItem(identifier: identifier)
  }
  
  func movePinnedItem(from: Int, to: Int) async {
    await tokenManagementStore.movePinnedItem(from: from, to: to)
  }
  
  private func didUpdateBalanceState(newState: [FriendlyAddress: ConvertedBalanceState],
                                     oldState: [FriendlyAddress: ConvertedBalanceState]?) async {
    await actor.addTask { [wallet] in
      guard let address = try? wallet.friendlyAddress,
      let balanceState = newState[address],
      balanceState != oldState?[address] else {
        return
      }
    
      let tokenManagementState = self.tokenManagementStore.getState()
      let stackingPools = self.stackingPoolsStore.getState()[address] ?? []
      
      let state = self.createState(
        balance: balanceState.balance,
        tokenManagementState: tokenManagementState,
        stackingPools: stackingPools
      )
      self.didUpdateState?(state)
    }
  }
  
  private func didUpdateTokenManagementState(newState: TokenManagementState,
                                             oldState: TokenManagementState?) async {
    await actor.addTask {
      guard newState != oldState,
            let address = try? self.wallet.friendlyAddress,
            let balance = self.convertedBalanceStore.getState()[address]?.balance else {
        return
      }
      
      let stackingPools = self.stackingPoolsStore.getState()[address] ?? []
      
      let state = self.createState(
        balance: balance,
        tokenManagementState: newState,
        stackingPools: stackingPools
      )
      self.didUpdateState?(state)
    }
  }
  
  private func createState(balance: ConvertedBalance, 
                           tokenManagementState: TokenManagementState,
                           stackingPools: [StackingPoolInfo]) -> State {
    
    let balanceItems = BalanceItems(
      balance: balance,
      stackingPools: stackingPools
    )
    
    var pinnedItems = [BalanceItem]()
    var unpinnedItems = [UnpinnedItem]()
    
    for item in balanceItems.items {
      if tokenManagementState.pinnedItems.contains(item.identifier) {
        pinnedItems.append(item)
      } else {
        let isHidden = tokenManagementState.hiddenItems.contains(item.identifier)
        unpinnedItems.append(UnpinnedItem(item: item, isHidden: isHidden))
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
      switch ($0.item, $1.item) {
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
        if lModel.jetton.jettonInfo.address == JettonMasterAddress.tonUSDT {
          return true
        }
        if rModel.jetton.jettonInfo.address == JettonMasterAddress.tonUSDT {
          return false
        }
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

    return State(pinnedItems: sortedPinnedItems, unpinnedItems: sortedUnpinnedItems)
  }
}

extension BalanceItem {
  var identifier: String {
    switch self {
    case .ton:
      return TonInfo.symbol
    case .jetton(let jetton):
      return jetton.jetton.jettonInfo.address.toRaw()
    case .staking(let staking):
      return staking.info.pool.toRaw()
    }
  }
}
