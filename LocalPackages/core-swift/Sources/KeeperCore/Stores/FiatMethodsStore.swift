import Foundation

public final class FiatMethodsStore: StoreV3<FiatMethodsStore.Event, FiatMethodsStore.State> {
  public enum State: Equatable {
    case none
    case loading
    case fiatMethods(FiatMethods)
  }
  
  public enum Event {
    case didUpdateState(state: State)
  }
  
  init() {
    super.init(state: .none)
  }
  
  public override var initialState: State {
    .none
  }
  
  public func updateState(_ state: State) async {
    await setState { _ in
      return StateUpdate(newState: state)
    } notify: { state in
      self.sendEvent(.didUpdateState(state: state))
    }
  }
}
