import Foundation

public final class AppSettingsStore: Store<AppSettingsStore.Event, AppSettingsStore.State> {
  public struct State {
    public var isSecureMode: Bool
    public var searchEngine: SearchEngine
  }
  
  public enum Event {
    case didUpdateIsSecureMode(isSecureMode: Bool)
    case didUpdateSearchEngine
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  public override func createInitialState() -> State {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State(isSecureMode: false, searchEngine: .duckduckgo))
  }

  @discardableResult
  public func toggleIsSecureMode() async -> State {
    return await withCheckedContinuation { continuation in
      toggleIsSecureMode { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func setIsSecureMode(_ isSecureMode: Bool) async -> State {
    return await withCheckedContinuation { continuation in
      setIsSecureMode(isSecureMode) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func setSearchEngine(_ searchEngine: SearchEngine) async -> State {
    return await withCheckedContinuation { continuation in
      setSearchEngine(searchEngine) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  public func toggleIsSecureMode(completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo = keeperInfo else { return nil }
      let updateKeeperInfo = keeperInfo.updateIsSecureMode(!keeperInfo.appSettings.isSecureMode)
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didUpdateIsSecureMode(isSecureMode: state.isSecureMode))
        completion(state)
      }
    }
  }
  
  public func setIsSecureMode(_ isSecureMode: Bool,
                              completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updateKeeperInfo = keeperInfo?.updateIsSecureMode(isSecureMode)
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didUpdateIsSecureMode(isSecureMode: state.isSecureMode))
        completion(state)
      }
    }
  }
  
  public func setSearchEngine(_ searchEngine: SearchEngine, 
                              completion: ((State) -> Void)? = nil) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updatedKeeperInfo = keeperInfo?.updateSearchEngine(searchEngine)
      return updatedKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didUpdateSearchEngine)
        completion?(state)
      }
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> State {
    guard let keeperInfo = keeperInfoStore.state else {
      return State(isSecureMode: false, searchEngine: .duckduckgo)
    }
    return State(isSecureMode: keeperInfo.appSettings.isSecureMode, searchEngine: keeperInfo.appSettings.searchEngine)
  }
}
