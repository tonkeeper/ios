import Foundation

public final class RegionStore: StoreV3<RegionStore.Event, SelectedCountry> {

  public enum Event {
    case didUpdateRegion(_ country: SelectedCountry)
  }

  public override var initialState: SelectedCountry {
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

  public func updateRegion(_ selectedCountry: SelectedCountry) async {
    await setState { state in
      return StateUpdate(newState: selectedCountry)
    } notify: { [weak self] country in
      guard let self = self else {
        return
      }
      
      self.sendEvent(.didUpdateRegion(country))
    }

    await keeperInfoStore.updateKeeperInfo { $0?.updateRegion(selectedCountry) }
  }
}
