import Foundation

public final class TokenManagementStore: Store<TokenManagementStore.Event, TokenManagementStore.State> {
  public typealias State = [Wallet: TokenManagementState]
  
  public enum Event {
    case didUpdateState(wallet: Wallet)
  }
  
  private let walletsStore: WalletsStore
  private let tokenManagementRepository: TokenManagementRepository
  
  init(walletsStore: WalletsStore, 
       tokenManagementRepository: TokenManagementRepository) {
    self.walletsStore = walletsStore
    self.tokenManagementRepository = tokenManagementRepository
    super.init(state: State())
    
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .didAddWallets(let wallets):
        self.updateState { state in
          var updatedState = state
          for wallet in wallets {
            let walletState = tokenManagementRepository.getState(wallet: wallet)
            updatedState[wallet] = walletState
          }
          return StateUpdate(newState: updatedState)
        } completion: { [weak self] _ in
          for wallet in wallets {
            self?.sendEvent(.didUpdateState(wallet: wallet))
          }
        }
      default: break
      }
    }
  }
  
  public override func createInitialState() -> State {
    let wallets = walletsStore.wallets
    var state = State()
    wallets.forEach { wallet in
      let walletState = tokenManagementRepository.getState(wallet: wallet)
      state[wallet] = walletState
    }
    return state
  }
  
  public func pinItem(identifier: String,
                      wallet: Wallet) async {
    return await withCheckedContinuation { continuation in
      pinItem(identifier: identifier, wallet: wallet) {
        continuation.resume()
      }
    }
  }
  
  public func unpinItem(identifier: String,
                        wallet: Wallet) async {
    return await withCheckedContinuation { continuation in
      unpinItem(identifier: identifier, wallet: wallet) {
        continuation.resume()
      }
    }
  }
  
  public func hideItem(identifier: String,
                       wallet: Wallet) async {
    return await withCheckedContinuation { continuation in
      hideItem(identifier: identifier, wallet: wallet) {
        continuation.resume()
      }
    }
  }
  
  public func unhideItem(identifier: String,
                         wallet: Wallet) async {
    return await withCheckedContinuation { continuation in
      unhideItem(identifier: identifier, wallet: wallet) {
        continuation.resume()
      }
    }
  }
  
  public func movePinnedItem(from: Int,
                             to: Int,
                             wallet: Wallet) async {
    return await withCheckedContinuation { continuation in
      movePinnedItem(
        from: from,
        to: to,
        wallet: wallet) {
          continuation.resume()
        }
    }
  }
  
  
  public func pinItem(identifier: String,
                      wallet: Wallet,
                      completion: (() -> Void)? = nil) {
    updateState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      var updatedPinnedItems = walletState.pinnedItems
      updatedPinnedItems.append(identifier)
      let walletUpdatedState = TokenManagementState(
        pinnedItems: updatedPinnedItems,
        hiddenState: walletState.hiddenState
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } completion: { [weak self] _ in
      self?.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }
  
  public func unpinItem(identifier: String, 
                        wallet: Wallet,
                        completion: (() -> Void)? = nil) {
    updateState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      let updatedPinnedItems = walletState.pinnedItems.filter { $0 != identifier }
      let walletUpdatedState = TokenManagementState(
        pinnedItems: updatedPinnedItems,
        hiddenState: walletState.hiddenState
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } completion: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }
  
  public func hideItem(identifier: String,
                       wallet: Wallet,
                       completion: (() -> Void)? = nil) {
    updateState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      var updatedHiddenItems = walletState.hiddenState
      updatedHiddenItems[identifier] = true
      let walletUpdatedState = TokenManagementState(
        pinnedItems: walletState.pinnedItems,
        hiddenState: updatedHiddenItems
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } completion: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }
  
  public func unhideItem(identifier: String,
                         wallet: Wallet,
                         completion: (() -> Void)? = nil) {
    updateState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      var updatedHiddenItems = walletState.hiddenState
      updatedHiddenItems[identifier] = false
      let walletUpdatedState = TokenManagementState(
        pinnedItems: walletState.pinnedItems,
        hiddenState: updatedHiddenItems
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } completion: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }
  
  public func movePinnedItem(from: Int,
                             to: Int,
                             wallet: Wallet,
                             completion: (() -> Void)? = nil) {
    updateState { [tokenManagementRepository] state in
      guard let walletState = state[wallet] else {
        return nil
      }
      var pinnedItems = walletState.pinnedItems
      let item = pinnedItems.remove(at: from)
      pinnedItems.insert(item, at: to)
      let walletUpdatedState = TokenManagementState(
        pinnedItems: pinnedItems,
        hiddenState: walletState.hiddenState
      )
      var updatedState = state
      updatedState[wallet] = walletUpdatedState
      try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } completion: { _ in
      self.sendEvent(.didUpdateState(wallet: wallet))
      completion?()
    }
  }
}
