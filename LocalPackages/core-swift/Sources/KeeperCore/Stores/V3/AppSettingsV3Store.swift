import Foundation

public final class AppSettingsV3Store: StoreV3<AppSettingsV3Store.Event, AppSettingsV3Store.State> {
  public struct State {
    public var isSetupFinished: Bool
    public var isSecureMode: Bool
  }
  
  public enum Event {
    case didUpdateIsSetupFinished(isSetupFinished: Bool)
    case didUpdateIsSecureMode(isSecureMode: Bool)
  }
  
  private let keeperInfoStore: KeeperInfoStoreV3
  
  public override var initialState: State {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStoreV3) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State(isSetupFinished: false, isSecureMode: false))
  }
  
  public func setIsSetupFinished(_ isSetupFinished: Bool) async {
    await setState { state in
      var updatedState = state
      updatedState.isSetupFinished = isSetupFinished
      return StateUpdate(newState: updatedState)
    } notify: {
      self.sendEvent(.didUpdateIsSetupFinished(isSetupFinished: isSetupFinished))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateIsSetupFinished(isSetupFinished)
      return updated
    }
  }
  
  public func toggleIsSecureMode() async {
    var isSecureMode = false
    await setState { state in
      var updatedState = state
      updatedState.isSecureMode = !state.isSecureMode
      isSecureMode = !state.isSecureMode
      return StateUpdate(newState: updatedState)
    } notify: {
      self.sendEvent(.didUpdateIsSecureMode(isSecureMode: isSecureMode))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateIsSecureMode(isSecureMode)
      return updated
    }
  }
  
  public func setIsSecureMode(_ isSecureMode: Bool) async {
    await setState { state in
      var updatedState = state
      updatedState.isSecureMode = isSecureMode
      return StateUpdate(newState: updatedState)
    } notify: {
      self.sendEvent(.didUpdateIsSecureMode(isSecureMode: isSecureMode))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateIsSecureMode(isSecureMode)
      return updated
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> State {
    if let keeperInfo = keeperInfoStore.getState() {
      return State(
        isSetupFinished: keeperInfo.appSettings.isSetupFinished,
        isSecureMode: keeperInfo.appSettings.isSecureMode
      )
    } else {
      return State(
        isSetupFinished: false,
        isSecureMode: false
      )
    }
  }
}
