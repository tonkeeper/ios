import Foundation

public final class SetupStore: StoreUpdated<SetupStore.State> {
  public struct State: Equatable {
    public let isSetupFinished: Bool
    
    static var defaultState: State {
      State(isSetupFinished: false)
    }
    
    static func state(keeperInfo: KeeperInfo?) -> State {
      guard let keeperInfo else {
        return .defaultState
      }
      let state = State(isSetupFinished: keeperInfo.appSettings.isSetupFinished)
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
        guard newState?.appSettings.isSetupFinished != oldState?.appSettings.isSetupFinished else {
          return
        }
        observer.didUpdateKeeperInfo(newState)
      }
  }
  
  public func getIsSetupFinished() -> Bool {
    getState().isSetupFinished
  }
  
  public func getIsSetupFinished() async -> Bool {
    await getState().isSetupFinished
  }
  
  public func setIsSetupFinished(_ isSetupFinished: Bool, completion: (() -> Void)? = nil) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      keeperInfo?.setIsSetupFinished(isSetupFinished)
    } completion: { [weak self] in
      guard let self else { return }
      updateState { _ in
        return StateUpdate(newState: State(isSetupFinished: isSetupFinished))
      } completion: {
        completion?()
      }
    }
  }
  
  public func setIsSetupFinished(_ isSetupFinished: Bool) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      keeperInfo?.setIsSetupFinished(isSetupFinished)
    }
    await updateState { _ in
      return StateUpdate(newState: State(isSetupFinished: isSetupFinished))
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
