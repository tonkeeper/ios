import Foundation

public final class BackgroundUpdateStoreV3: StoreV3<BackgroundUpdateStoreV3.Event, BackgroundUpdateStoreV3.State> {
  public enum State: Equatable {
    case connecting
    case connected
    case disconnected
    case noConnection
  }
  
  public enum Event {
    case didUpdateState(State)
  }
  
  public init() {
    super.init(state: .disconnected)
  }
  
  public override var initialState: State {
    .disconnected
  }
  
  public func setState(_ state: State) async {
    await setState { _ in
      StateUpdate(newState: state)
    } notify: {
      self.sendEvent(.didUpdateState(state))
    }
  }
}
