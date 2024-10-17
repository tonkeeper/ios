import Foundation

public final class SearchEngineStore: StoreV3<SearchEngineStore.Event, SearchEngine> {

  public enum Event {
    case didUpdateSearchEngine(_ searchEngine: SearchEngine)
  }

  public override var initialState: SearchEngine {
    if let info = keeperInfoStore.getState() {
      info.searchEngine
    } else {
      .duckduckgo
    }
  }

  private let keeperInfoStore: KeeperInfoStore

  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: .duckduckgo)
  }

  public func updateSearchEngine(_ searchEngine: SearchEngine) async {
    await setState { state in
      return StateUpdate(newState: searchEngine)
    } notify: { [weak self] country in
      guard let self = self else {
        return
      }

      self.sendEvent(.didUpdateSearchEngine(country))
    }

    await keeperInfoStore.updateKeeperInfo { $0?.updateSearchEngine(searchEngine) }
  }
}
