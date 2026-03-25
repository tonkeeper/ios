import Foundation

public final class AppSettingsStore: Store<AppSettingsStore.Event, AppSettingsStore.State> {
    public struct State {
        public var isSecureMode: Bool
        public var searchEngine: SearchEngine
    }

    public enum Event {
        case didUpdateIsSecureMode(isSecureMode: Bool)
        case didUpdateSearchEngine
    }

    private let keeperInfoStore: KeeperInfoStore

    override public func createInitialState() -> State {
        getState(keeperInfo: keeperInfoStore.getState())
    }

    init(keeperInfoStore: KeeperInfoStore) {
        self.keeperInfoStore = keeperInfoStore
        super.init(state: State(isSecureMode: false, searchEngine: .duckduckgo))
    }

    public func toggleIsSecureMode(completion: ((State) -> Void)? = nil) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo = keeperInfo else { return nil }
            return keeperInfo.updateIsSecureMode(!keeperInfo.appSettings.isSecureMode)
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(.didUpdateIsSecureMode(isSecureMode: state.isSecureMode))
                completion?(state)
            }
        }
    }

    public func setSearchEngine(
        _ searchEngine: SearchEngine,
        completion: ((State) -> Void)? = nil
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            keeperInfo?.updateSearchEngine(searchEngine)
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(.didUpdateSearchEngine)
                completion?(state)
            }
        }
    }

    private func getState(keeperInfo: KeeperInfo?) -> State {
        guard let keeperInfo = keeperInfoStore.state else {
            return State(isSecureMode: false, searchEngine: .duckduckgo)
        }
        return State(isSecureMode: keeperInfo.appSettings.isSecureMode, searchEngine: keeperInfo.appSettings.searchEngine)
    }
}
