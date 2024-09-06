import Foundation

public final class TokenManagementStore: StoreV3<TokenManagementStore.Event, TokenManagementStore.State> {
  public typealias State = [Wallet: TokenManagementState]
  
  public enum Event {
    case didUpdateState(wallet: Wallet)
  }
  
  private let walletsStore: WalletsStoreV3
  private let tokenManagementRepository: TokenManagementRepository
  
  init(walletsStore: WalletsStoreV3, 
       tokenManagementRepository: TokenManagementRepository) {
    self.walletsStore = walletsStore
    self.tokenManagementRepository = tokenManagementRepository
    super.init(state: State())
  }
  
  public override var initialState: State {
    let wallets = walletsStore.wallets
    var state = State()
    wallets.forEach { wallet in
      let walletState = tokenManagementRepository.getState(wallet: wallet)
      state[wallet] = walletState
    }
    return state
  }
  
  public func pinItem(identifier: String, wallet: Wallet) async {
    await setState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      var updatedPinnedItems = walletState.pinnedItems
      updatedPinnedItems.append(identifier)
      let walletUpdatedState = TokenManagementState(
        pinnedItems: updatedPinnedItems,
        hiddenItems: walletState.hiddenItems
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
    }
  }
  
  public func unpinItem(identifier: String, wallet: Wallet) async {
    await setState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      let updatedPinnedItems = walletState.pinnedItems.filter { $0 != identifier }
      let walletUpdatedState = TokenManagementState(
        pinnedItems: updatedPinnedItems,
        hiddenItems: walletState.hiddenItems
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
    }
  }
  
  public func hideItem(identifier: String, wallet: Wallet) async {
    await setState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      var updatedHiddenItems = walletState.hiddenItems
      updatedHiddenItems.append(identifier)
      let walletUpdatedState = TokenManagementState(
        pinnedItems: walletState.pinnedItems,
        hiddenItems: updatedHiddenItems
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
    }
  }
  
  public func unhideItem(identifier: String, wallet: Wallet) async {
    await setState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      let updatedHiddenItems = walletState.hiddenItems.filter { $0 != identifier }
      let walletUpdatedState = TokenManagementState(
        pinnedItems: walletState.pinnedItems,
        hiddenItems: updatedHiddenItems
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
    }
  }
  
  public func movePinnedItem(from: Int, to: Int, wallet: Wallet) async {
    await setState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      var pinnedItems = walletState.pinnedItems
      let item = pinnedItems.remove(at: from)
      pinnedItems.insert(item, at: to)
      let walletUpdatedState = TokenManagementState(
        pinnedItems: pinnedItems,
        hiddenItems: walletState.hiddenItems
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
    }
  }
}
