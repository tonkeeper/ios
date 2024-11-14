import Foundation

public enum BatteryPromocodeResolveState: Equatable {
  case none
  case success(promocode: String)
  case failed(promocode: String)
  case resolving(promocode: String)
}


public final class BatteryPromocodeStore: Store<BatteryPromocodeStore.Event, BatteryPromocodeResolveState> {
  public enum Event {
    case didUpdateResolverState
  }
  
  private let repository: BatteryPromocodeRepository

  init(repository: BatteryPromocodeRepository) {
    self.repository = repository
    super.init(state: .none)
  }
  
  public override func createInitialState() -> BatteryPromocodeResolveState {
    guard let promocode = repository.getPromocode() else {
      return .none
    }
    return .success(promocode: promocode)
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
    updateState { [repository] _ in
      switch resolveState {
      case .none:
        try? repository.savePromocode(nil)
      case .success(let promocode):
        try? repository.savePromocode(promocode)
      case .failed(let promocode):
        try? repository.savePromocode(nil)
      case .resolving(let promocode):
        try? repository.savePromocode(nil)
      }
      return StateUpdate(newState: resolveState)
    } completion: { [weak self] _ in
      guard let self else { return }
      self.sendEvent(.didUpdateResolverState)
      completion?()
    }
  }
}
