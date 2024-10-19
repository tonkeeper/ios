import Foundation

public final class AppSettingsV3Store: StoreV3<AppSettingsV3Store.Event, AppSettingsV3Store.State> {
  public struct State {
    public var isSecureMode: Bool
  }
  
  public enum Event {
    case didUpdateIsSetupFinished(isSetupFinished: Bool)
    case didUpdateIsSecureMode(isSecureMode: Bool)
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  public override func createInitialState() -> State {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State(isSecureMode: false))
  }
  
  public func toggleIsSecureMode() async {
    var isSecureMode = false
    await setState { state in
      var updatedState = state
      updatedState.isSecureMode = !state.isSecureMode
      isSecureMode = !state.isSecureMode
      return StateUpdate(newState: updatedState)
    } notify: { state in
      self.sendEvent(.didUpdateIsSecureMode(isSecureMode: state.isSecureMode))
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
    } notify: { state in
      self.sendEvent(.didUpdateIsSecureMode(isSecureMode: state.isSecureMode))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateIsSecureMode(isSecureMode)
      return updated
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> State {
    if let keeperInfo = keeperInfoStore.getState() {
      return State(
        isSecureMode: keeperInfo.appSettings.isSecureMode
      )
    } else {
      return State(
        isSecureMode: false
      )
    }
  }
}
