import Foundation

public final class SecurityStore: StoreV3<SecurityStore.Event, SecurityStore.State> {
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
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .defaultState)
  }
  
  public override func createInitialState() -> State {
    State.state(keeperInfo: keeperInfoStore.getState())
  }
  
  public func setIsBiometryEnable(_ isBiometryEnable: Bool) async -> State {
    return await withCheckedContinuation { continuation in
      setIsBiometryEnable(isBiometryEnable) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  public func setIsLockScreen(_ isLockScreen: Bool) async -> State {
    return await withCheckedContinuation { continuation in
      setIsLockScreen(isLockScreen) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  public func setIsBiometryEnable(_ isBiometryEnable: Bool,
                                  completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updateKeeperInfo = keeperInfo?.updateIsBiometryEnable(isBiometryEnable)
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = State.state(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didUpdateIsBiometryEnabled(isBiometryEnable: isBiometryEnable))
        completion(state)
      }
    }
  }
  
  public func setIsLockScreen(_ isLockScreen: Bool,
                              completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updateKeeperInfo = keeperInfo?.updateIsLockScreen(isLockScreen)
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = State.state(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didUpdateIsLockScreen(isLockScreen: isLockScreen))
        completion(state)
      }
    }
  }
}
