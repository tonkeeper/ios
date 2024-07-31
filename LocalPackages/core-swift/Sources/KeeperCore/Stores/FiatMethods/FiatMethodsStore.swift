import Foundation

public final class FiatMethodsStore: StoreUpdated<FiatMethodsStore.State> {
  public enum State: Equatable {
    case none
    case loading
    case fiatMethods(FiatMethods)
  }
  
  init() {
    super.init(state: .none)
  }
  
  public override func getInitialState() -> State {
    .none
  }
}
