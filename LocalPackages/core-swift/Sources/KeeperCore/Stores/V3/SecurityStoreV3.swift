import Foundation

public final class SecurityStoreV3: StoreV3<SecurityStoreV3.Event, SecurityStoreV3.State> {
  public struct State {
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
  
  public enum Event {
    case didUpdateIsBiometryEnabled(isBiometryEnable: Bool)
    case didUpdateIsLockScreen(isLockScreen: Bool)
  }
  
  private let keeperInfoStore: KeeperInfoStoreV3
  
  init(keeperInfoStore: KeeperInfoStoreV3) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .defaultState)
  }
  
  public override var initialState: State {
    State.state(keeperInfo: keeperInfoStore.getState())
  }
  
  public func setIsBiometryEnable(_ isBiometryEnable: Bool) async {
    await setState { state in
      let updatedState = State(isBiometryEnable: isBiometryEnable,
                               isLockScreen: state.isLockScreen)
      return StateUpdate(newState: updatedState)
    } notify: { state in
      self.sendEvent(.didUpdateIsBiometryEnabled(isBiometryEnable: state.isBiometryEnable))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateIsBiometryEnable(isBiometryEnable)
      return updated
    }
  }
  
  public func setIsLockScreen(_ isLockScreen: Bool) async {
    await setState { state in
      let updatedState = State(isBiometryEnable: state.isBiometryEnable,
                               isLockScreen: isLockScreen)
      return StateUpdate(newState: updatedState)
    } notify: { state in
      self.sendEvent(.didUpdateIsLockScreen(isLockScreen: state.isLockScreen))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateIsLockScreen(isLockScreen)
      return updated
    }
  }
}
