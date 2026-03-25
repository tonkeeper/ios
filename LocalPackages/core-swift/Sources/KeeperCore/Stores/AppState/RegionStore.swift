import Foundation

public final class RegionStore: Store<RegionStore.Event, SelectedCountry> {
    public enum Event {
        case didUpdateRegion(_ country: SelectedCountry)
    }

    override public func createInitialState() -> SelectedCountry {
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
}
