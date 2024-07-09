import Foundation

public final class TokenManagementStore: Store<TokenManagementState> {
  private let wallet: Wallet
  private let tokenManagementRepository: TokenManagementRepository
  
  func updateState(_ block: @escaping (TokenManagementState) -> TokenManagementState) async {
    await updateState { [tokenManagementRepository, wallet] state in
      let updated = block(state)
      try? tokenManagementRepository.setState(updated, wallet: wallet)
      return StateUpdate(newState: updated)
    }
  }
  
  init(wallet: Wallet,
       tokenManagementRepository: TokenManagementRepository) {
    self.wallet = wallet
    self.tokenManagementRepository = tokenManagementRepository
    super.init(state: TokenManagementState(pinnedItems: [], hiddenItems: []))
    Task {
      await updateState { _ in
        StateUpdate(newState: tokenManagementRepository.getState(wallet: wallet))
      }
    }
  }
  
 public func pinItem(identifier: String) async {
    await updateState { state in
      var updatedPinnedItems = state.pinnedItems
      updatedPinnedItems.append(identifier)
      let updatedState = TokenManagementState(
        pinnedItems: updatedPinnedItems,
        hiddenItems: state.hiddenItems
      )
      try? self.tokenManagementRepository.setState(updatedState, wallet: self.wallet)
      return StateUpdate(newState: updatedState)
    }
 }
  
  public func unpinItem(identifier: String) async {
    await updateState { state in
      let updatedPinnedItems = state.pinnedItems.filter { $0 != identifier }
      let updatedState = TokenManagementState(
        pinnedItems: updatedPinnedItems,
        hiddenItems: state.hiddenItems
      )
      try? self.tokenManagementRepository.setState(updatedState, wallet: self.wallet)
      return StateUpdate(newState: updatedState)
    }
  }
  
  public func hideItem(identifier: String) async {
    await updateState { state in
      var updatedHiddenItems = state.hiddenItems
      updatedHiddenItems.append(identifier)
      let updatedState = TokenManagementState(
        pinnedItems: state.pinnedItems,
        hiddenItems: updatedHiddenItems
      )
      try? self.tokenManagementRepository.setState(updatedState, wallet: self.wallet)
      return StateUpdate(newState: updatedState)
    }
  }
  
  public func unhideItem(identifier: String) async {
    await updateState { state in
      let updatedHiddenItems = state.hiddenItems.filter { $0 != identifier }
      let updatedState = TokenManagementState(
        pinnedItems: state.pinnedItems,
        hiddenItems: updatedHiddenItems
      )
      try? self.tokenManagementRepository.setState(updatedState, wallet: self.wallet)
      return StateUpdate(newState: updatedState)
    }
  }
  
  public func movePinnedItem(from: Int, to: Int) async {
    await updateState { state in
      var pinnedItems = state.pinnedItems
      let item = pinnedItems.remove(at: from)
      pinnedItems.insert(item, at: to)
      let updatedState = TokenManagementState(
        pinnedItems: pinnedItems,
        hiddenItems: state.hiddenItems
      )
      try? self.tokenManagementRepository.setState(updatedState, wallet: self.wallet)
      return StateUpdate(newState: updatedState)
    }
  }
}
