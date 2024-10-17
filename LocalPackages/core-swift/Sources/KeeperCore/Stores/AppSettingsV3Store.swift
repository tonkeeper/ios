import Foundation

public final class AppSettingsV3Store: StoreV3<AppSettingsV3Store.Event, AppSettingsV3Store.State> {

  public struct State {
    public var isSecureMode: Bool
    public var searchEngine: SearchEngine
  }
  
  public enum Event {
    case didUpdateIsSetupFinished(isSetupFinished: Bool)
    case didUpdateIsSecureMode(isSecureMode: Bool)
    case didUpdateSearchEngine(searchEngine: SearchEngine)
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  public override var initialState: State {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State(isSecureMode: false,
                            searchEngine: .duckduckgo))
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

  public func updateSearchEngine(_ searchEngine: SearchEngine) async {
    await setState { state in
      var updatedState = state
      updatedState.searchEngine = searchEngine
      return StateUpdate(newState: updatedState)
    } notify: { state in
      self.sendEvent(.didUpdateSearchEngine(searchEngine: state.searchEngine))
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updated = keeperInfo?.updateSearchEngine(searchEngine)
      return updated
    }
  }

  private func getState(keeperInfo: KeeperInfo?) -> State {
    if let keeperInfo = keeperInfoStore.getState() {
      return State(
        isSecureMode: keeperInfo.appSettings.isSecureMode,
        searchEngine: keeperInfo.appSettings.searchEngine
      )
    } else {
      return State(
        isSecureMode: false,
        searchEngine: .duckduckgo
      )
    }
  }
}
