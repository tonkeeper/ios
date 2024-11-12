import Foundation

public final class RegionStore: Store<RegionStore.Event, SelectedCountry> {
  
  public enum Event {
    case didUpdateRegion(_ country: SelectedCountry)
  }
  
  public override func createInitialState() -> SelectedCountry {
    if let info = keeperInfoStore.getState() {
      info.country
    } else {
      .auto
    }
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .auto)
  }
  
  @discardableResult
  public func setRegion(_ region: SelectedCountry) async -> SelectedCountry {
    return await withCheckedContinuation { continuation in
      setRegion(region) { region in
        continuation.resume(returning: region)
      }
    }
  }
  
  public func setRegion(_ region: SelectedCountry,
                        completion: @escaping (SelectedCountry) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updatedKeeperInfo = keeperInfo?.updateRegion(region)
      return updatedKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      updateState { _ in
        return StateUpdate(newState: region)
      } completion: { [weak self] region in
        self?.sendEvent(.didUpdateRegion(region))
        completion(region)
      }
    }
  }
}
