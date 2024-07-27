import Foundation

public final class SecurityStoreV2: StoreUpdated<SecurityStoreV2.State> {
  public struct State: Equatable {
    public let isBiometryEnable: Bool
    public let isLockScreen: Bool
    
    static var defaultState: State {
      State(isBiometryEnable: false, isLockScreen: false)
    }
    
    static func state(keeperInfo: KeeperInfo?) -> State {
      guard let keeperInfo else {
        return .defaultState
      }
      let state = State(
        isBiometryEnable: keeperInfo.securitySettings.isBiometryEnabled,
        isLockScreen: keeperInfo.securitySettings.isLockScreen
      )
      return state
    }
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .defaultState)
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
        observer.didUpdateKeeperInfo(newState)
      }
  }
  
  public func getIsBiometryEnable() -> Bool {
    getState().isBiometryEnable
  }
  
  public func getIsBiometryEnable() async -> Bool {
    await getState().isBiometryEnable
  }
  
  public func setIsBiometryEnable(_ isBiometryEnable: Bool, completion: (() -> Void)? = nil) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      keeperInfo?.setIsBiometryEnabled(isBiometryEnable)
    } completion: { [weak self] in
      guard let self else { return }
      updateState { state in
        let updatedState = State(
          isBiometryEnable: isBiometryEnable,
          isLockScreen: state.isLockScreen
        )
        return StateUpdate(newState: updatedState)
      } completion: {
        completion?()
      }
    }
  }
  
  public func setIsBiometryEnable(_ isBiometryEnable: Bool) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      keeperInfo?.setIsBiometryEnabled(isBiometryEnable)
    }
    await updateState { state in
      let updatedState = State(
        isBiometryEnable: isBiometryEnable,
        isLockScreen: state.isLockScreen
      )
      return StateUpdate(newState: updatedState)
    }
  }
  
  public func getIsLockScreen() -> Bool {
    getState().isLockScreen
  }
  
  public func getIsLockScreen() async -> Bool {
    await getState().isLockScreen
  }
  
  public func setIsLockScreen(_ isLockScreen: Bool, completion: (() -> Void)? = nil) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      keeperInfo?.setIsLockScreen(isLockScreen)
    } completion: { [weak self] in
      guard let self else { return }
      updateState { state in
        let updatedState = State(
          isBiometryEnable: state.isBiometryEnable,
          isLockScreen: isLockScreen
        )
        return StateUpdate(newState: updatedState)
      } completion: {
        completion?()
      }
    }
  }
  
  public func setIsLockScreen(_ isLockScreen: Bool) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      keeperInfo?.setIsLockScreen(isLockScreen)
    }
    await updateState { state in
      let updatedState = State(
        isBiometryEnable: state.isBiometryEnable,
        isLockScreen: isLockScreen
      )
      return StateUpdate(newState: updatedState)
    }
  }
 
  public override func getInitialState() -> State {
    State.state(keeperInfo: keeperInfoStore.getState())
  }
  
  private func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    updateState { _ in
      StateUpdate(newState: .state(keeperInfo: keeperInfo))
    }
  }
}
