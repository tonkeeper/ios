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
    
    convertedBalanceStore.addObserver(self) { observer, event in
      observer.didGetBalanceStateEvent(event)
    }
    
    tokenManagementStore.addObserver(self) { observer, event in
      observer.didGetTokenManagmentStoreEvent(event)
    }
  }
  
  func getState() -> State {
    guard let balance = convertedBalanceStore.getState()[wallet]?.balance else {
      return State(pinnedItems: [], unpinnedItems: [])
    }
    
    let tokenManagementState = tokenManagementStore.getState()[wallet]
    let stackingPools = stackingPoolsStore.getState()[wallet] ?? []
    
    return createState(
      balance: balance,
      tokenManagementState: tokenManagementState,
      stackingPools: stackingPools
    )
  }
  
  func getState() async -> State {
    guard let balance = await convertedBalanceStore.getState()[wallet]?.balance else {
      return State(pinnedItems: [], unpinnedItems: [])
    }
    
    let tokenManagementState = await tokenManagementStore.getState()[wallet]
    let stackingPools = await stackingPoolsStore.getState()[wallet] ?? []
    
    return createState(
      balance: balance,
      tokenManagementState: tokenManagementState,
      stackingPools: stackingPools
    )
  }
  
  func pinItem(identifier: String) {
    Task {
      await tokenManagementStore.pinItem(identifier: identifier, wallet: wallet)
    }
  }
  
  func unpinItem(identifier: String) {
    Task {
      await tokenManagementStore.unpinItem(identifier: identifier, wallet: wallet)
    }
  }
  
  func hideItem(identifier: String) {
    Task {
      await tokenManagementStore.hideItem(identifier: identifier, wallet: wallet)
    }
  }
  
  func unhideItem(identifier: String) {
    Task {
      await tokenManagementStore.unhideItem(identifier: identifier, wallet: wallet)
    }
  }
  
  func movePinnedItem(from: Int, to: Int) {
    Task {
      await tokenManagementStore.movePinnedItem(from: from, to: to, wallet: wallet)
    }
  }
  
  private func didGetBalanceStateEvent(_ event: ConvertedBalanceStore.Event) {
    switch event {
    case .didUpdateConvertedBalance(_, let wallet):
      guard wallet == self.wallet else { return }
      Task {
        await actor.addTask { [wallet] in
          guard let balance = await self.convertedBalanceStore.getState()[wallet]?.balance else { return }
          let tokenManagementState = await self.tokenManagementStore.getState()[wallet]
          let stackingPools = await self.stackingPoolsStore.getState()[wallet] ?? []
          
          let state = self.createState(
            balance: balance,
            tokenManagementState: tokenManagementState,
            stackingPools: stackingPools
          )
          self.didUpdateState?(state)
        }
      }
    }
  }
  
  private func didGetTokenManagmentStoreEvent(_ event: TokenManagementStore.Event) {
    switch event {
    case .didUpdateState(let wallet):
      guard wallet == self.wallet else { return }
      Task {
        await actor.addTask { [wallet] in
          guard let balance = await self.convertedBalanceStore.getState()[wallet]?.balance else { return }
          let tokenManagementState = await self.tokenManagementStore.getState()[wallet]
          let stackingPools = await self.stackingPoolsStore.getState()[wallet] ?? []
          
          let state = self.createState(
            balance: balance,
            tokenManagementState: tokenManagementState,
            stackingPools: stackingPools
          )
          self.didUpdateState?(state)
        }
      }
    }
  }

  private func createState(balance: ConvertedBalance, 
                           tokenManagementState: TokenManagementState?,
                           stackingPools: [StackingPoolInfo]) -> State {
    
    let balanceItems = BalanceItems(
      balance: balance,
      stackingPools: stackingPools
    )
    
    let statePinnedItems = tokenManagementState?.pinnedItems ?? []
    let stateHiddenItems = tokenManagementState?.hiddenItems ?? []
    var pinnedItems = [BalanceItem]()
    var unpinnedItems = [UnpinnedItem]()
    for item in balanceItems.items {
      if case .ton(_) = item {
        continue
      }
      
      if statePinnedItems.contains(item.identifier) {
        pinnedItems.append(item)
      } else {
        let isHidden = stateHiddenItems.contains(item.identifier)
        unpinnedItems.append(UnpinnedItem(item: item, isHidden: isHidden))
      }
    }
    
    let sortedPinnedItems = pinnedItems.sorted {
      guard let lIndex = statePinnedItems.firstIndex(of: $0.identifier) else {
        return false
      }
      guard let rIndex = statePinnedItems.firstIndex(of: $1.identifier) else {
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
