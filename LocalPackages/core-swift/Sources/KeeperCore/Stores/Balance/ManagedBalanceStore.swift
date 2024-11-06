import Foundation
import TonSwift
import BigInt

public struct ManagedBalance {
  public let tonItems: [ProcessedBalanceTonItem]
  public let pinnedItems: [ProcessedBalanceItem]
  public let unpinnedItems: [ProcessedBalanceItem]
  public let currency: Currency
  public let date: Date
  public let isManagable: Bool
}

public enum ManagedBalanceState {
  case current(ManagedBalance)
  case previous(ManagedBalance)
  
  public var balance: ManagedBalance? {
    switch self {
    case .current(let balance):
      return balance
    case .previous(let balance):
      return balance
    }
  }
}

public final class ManagedBalanceStore: Store<ManagedBalanceStore.Event, ManagedBalanceStore.State> {
  public typealias State = [Wallet: ManagedBalanceState]
  
  public enum Event {
    case didUpdateManagedBalance(wallet: Wallet)
  }
  
  private let balanceStore: ProcessedBalanceStore
  private let tokenManagementStore: TokenManagementStore
  
  init(balanceStore: ProcessedBalanceStore,
       tokenManagementStore: TokenManagementStore) {
    self.balanceStore = balanceStore
    self.tokenManagementStore = tokenManagementStore
    super.init(state: [:])
    setupObservers()
  }
  
  public override func createInitialState() -> State {
    let balanceStates = balanceStore.state
    let state = calculateState(wallets: balanceStates.keys.map { $0 as Wallet })
    return state
  }
  
  private func setupObservers() {
    balanceStore.addObserver(self) { observer, event in
      observer.didGetBalanceStoreEvent(event)
    }
    tokenManagementStore.addObserver(self) { observer, event in
      observer.didGetTokenManagementStoreEvent(event)
    }
  }
  
  private func didGetBalanceStoreEvent(_ event: ProcessedBalanceStore.Event) {
    switch event {
    case .didUpdateProccessedBalance(let wallet):
      updateState(wallets: [wallet])
    }
  }
  
  private func didGetStakingPoolsStoreEvent(_ event: StakingPoolsStore.Event) {
    switch event {
    case .didUpdateStakingPools(let wallet):
      updateState(wallets: [wallet])
    }
  }
  
  private func didGetTokenManagementStoreEvent(_ event: TokenManagementStore.Event) {
    switch event {
    case .didUpdateState(let wallet):
      updateState(wallets: [wallet])
    }
  }
  
  private func updateState(wallets: [Wallet]) {
    updateState { [weak self] state in
      guard let self else { return nil }
      let walletsState = calculateState(wallets: wallets)
      let updatedState = state.merging(walletsState, uniquingKeysWith: { $1 })
      return StateUpdate(newState: updatedState)
    } completion: { [weak self] _ in
      wallets.forEach { self?.sendEvent(.didUpdateManagedBalance(wallet: $0)) }
    }
  }

  private func calculateState(wallets: [Wallet]) -> State {
    guard !wallets.isEmpty else { return [:] }
    
    let balanceState = self.balanceStore.state
    let tokenManagementState = self.tokenManagementStore.state

    var state = State()
    for wallet in wallets {
      guard let walletBalanceState = balanceState[wallet] else { continue }
      let walletState = calculateState(
        wallet: wallet,
        balanceState: walletBalanceState,
        tokenManagementState: tokenManagementState[wallet]
      )
      state[wallet] = walletState
    }
    
    return state
  }
  
  private func calculateState(wallet: Wallet,
                              balanceState: ProcessedBalanceState,
                              tokenManagementState: TokenManagementState?) -> ManagedBalanceState? {
    let balance = balanceState.balance
    
    let statePinnedItems = tokenManagementState?.pinnedItems ?? []
    let stateHiddenItems = tokenManagementState?.hiddenState ?? [:]

    var tonItems = [ProcessedBalanceTonItem]()
    var pinnedItems = [ProcessedBalanceItem]()
    var unpinnedItems = [ProcessedBalanceItem]()
    
    for balanceItem in balance.items {
      switch balanceItem {
      case .ton(let tonItem):
        tonItems.append(tonItem)
      default:
        if statePinnedItems.contains(balanceItem.identifier) {
          pinnedItems.append(balanceItem)
        } else {
          let isHidden = {
            stateHiddenItems[balanceItem.identifier] == true || (stateHiddenItems[balanceItem.identifier] == nil && balanceItem.isZeroBalance)
          }()
          guard !isHidden else { continue }
          unpinnedItems.append(balanceItem)
        }
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
      switch ($0, $1) {
      case (.ton, _):
        return true
      case (_, .ton):
        return false
      case (.staking(let lModel), .staking(let rModel)):
        return lModel.amountConverted > rModel.amountConverted
      case (.staking, _):
        return true
      case (_, .staking):
        return false
      case (.jetton(let lModel), .jetton(let rModel)):
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
    
    let managedBalance = ManagedBalance(
      tonItems: tonItems,
      pinnedItems: sortedPinnedItems,
      unpinnedItems: sortedUnpinnedItems,
      currency: balance.currency,
      date: balance.date,
      isManagable: (balance.jettonItems.count + balance.stakingItems.count) > 0
    )
    
    switch balanceState {
    case .current:
      return .current(managedBalance)
    case .previous:
      return .previous(managedBalance)
    }
  }
}
