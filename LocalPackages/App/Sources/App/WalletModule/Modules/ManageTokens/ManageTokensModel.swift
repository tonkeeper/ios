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

  private let wallet: Wallet
  private let convertedBalanceStore: ConvertedBalanceStore
  private let tokenManagementStore: TokenManagementStore
  private let stackingPoolsStore: StakingPoolsStore
  private let updateQueue: DispatchQueue
  
  init(wallet: Wallet,
       tokenManagementStore: TokenManagementStore,
       convertedBalanceStore: ConvertedBalanceStore,
       stackingPoolsStore: StakingPoolsStore,
       updateQueue: DispatchQueue) {
    self.wallet = wallet
    self.tokenManagementStore = tokenManagementStore
    self.convertedBalanceStore = convertedBalanceStore
    self.stackingPoolsStore = stackingPoolsStore
    self.updateQueue = updateQueue
    
    convertedBalanceStore.addObserver(self) { observer, event in
      observer.didGetBalanceStateEvent(event)
    }
    
    tokenManagementStore.addObserver(self) { observer, event in
      observer.didGetTokenManagmentStoreEvent(event)
    }
  }
  
  func getState() -> State {
    guard let balance = convertedBalanceStore.state[wallet]?.balance else {
      return State(pinnedItems: [], unpinnedItems: [])
    }
    
    let tokenManagementState = tokenManagementStore.state[wallet]
    let stackingPools = stackingPoolsStore.state[wallet] ?? []
    
    return createState(
      balance: balance,
      tokenManagementState: tokenManagementState,
      stackingPools: stackingPools
    )
  }
  
  func pinItem(identifier: String) {
    tokenManagementStore.pinItem(identifier: identifier, wallet: wallet)
  }
  
  func unpinItem(identifier: String) {
    tokenManagementStore.unpinItem(identifier: identifier, wallet: wallet)
  }
  
  func hideItem(identifier: String) {
    tokenManagementStore.hideItem(identifier: identifier, wallet: wallet)
  }
  
  func unhideItem(identifier: String) {
    tokenManagementStore.unhideItem(identifier: identifier, wallet: wallet)
  }
  
  func movePinnedItem(from: Int, to: Int) {
    tokenManagementStore.movePinnedItem(from: from, to: to, wallet: wallet)
  }
  
  private func didGetBalanceStateEvent(_ event: ConvertedBalanceStore.Event) {
    updateQueue.async { [weak self] in
      guard let self else { return }
      switch event {
      case .didUpdateConvertedBalance(let wallet):
        guard wallet == self.wallet else { return }
        self.update()
      }
    }
  }
  
  private func didGetTokenManagmentStoreEvent(_ event: TokenManagementStore.Event) {
    updateQueue.async { [weak self] in
      guard let self else { return }
      switch event {
      case .didUpdateState(let wallet):
        guard wallet == self.wallet else { return }
        self.update()
      }
    }
  }
  
  private func update() {
    guard let balance = self.convertedBalanceStore.state[wallet]?.balance else { 
      self.didUpdateState?(State(pinnedItems: [], unpinnedItems: []))
      return
    }
    let tokenManagementState = tokenManagementStore.state[wallet]
    let stackingPools = stackingPoolsStore.state[wallet] ?? []
    
    let state = createState(
      balance: balance,
      tokenManagementState: tokenManagementState,
      stackingPools: stackingPools
    )
    
    didUpdateState?(state)
  }

  private func createState(balance: ConvertedBalance, 
                           tokenManagementState: TokenManagementState?,
                           stackingPools: [StackingPoolInfo]) -> State {
    
    let balanceItems = BalanceItems(
      balance: balance,
      stackingPools: stackingPools
    )
    
    let statePinnedItems = tokenManagementState?.pinnedItems ?? []
    let stateHiddenItems = tokenManagementState?.hiddenState ?? [:]
    var pinnedItems = [BalanceItem]()
    var unpinnedItems = [UnpinnedItem]()
    for item in balanceItems.items {
      if case .ton(_) = item {
        continue
      }
      if statePinnedItems.contains(item.identifier) {
        pinnedItems.append(item)
      } else {
        let isHidden = {
          stateHiddenItems[item.identifier] == true || (stateHiddenItems[item.identifier] == nil && item.isZeroBalance)
        }()
        
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
          if lModel.converted == rModel.converted {
            return lModel.amount > rModel.amount  
          } else {
            return lModel.converted > rModel.converted
          }
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
  
  var isZeroBalance: Bool {
    switch self {
    case .ton(let ton):
      return ton.amount == 0
    case .jetton(let jetton):
      return jetton.amount.isZero
    case .staking(let staking):
      return staking.info.amount == 0
    }
  }
}
