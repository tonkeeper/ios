import Foundation

public enum BatteryPromocodeResolveState {
  case none
  case success(promocode: String)
  case failed
  case resolving(promocode: String)
}


public final class BatteryPromocodeStore: Store<BatteryPromocodeStore.Event, BatteryPromocodeResolveState> {
  public enum Event {
    case didUpdateResolverState
  }
  
  init() {
    super.init(state: .none)
  }
  
  public override func createInitialState() -> BatteryPromocodeResolveState {
    .none
  }
  
  public func setResolveState(_ resolveState: BatteryPromocodeResolveState) async {
    return await withCheckedContinuation { continuation in
      setResolveState(resolveState) {
        continuation.resume()
      }
    }
  }
  
  public func setResolveState(_ resolveState: BatteryPromocodeResolveState,
                              completion: (() -> Void)? = nil) {
    updateState { _ in
      return StateUpdate(newState: resolveState)
    } completion: { [weak self] _ in
      guard let self else { return }
      self.sendEvent(.didUpdateResolverState)
      completion?()
    }
  }
}
