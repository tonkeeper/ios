import Foundation

public final class AppSettingsStore: Store<AppSettingsStore.Event, AppSettingsStore.State> {
    public struct State {
        public var isSecureMode: Bool
        public var searchEngine: SearchEngine
        public var hidesDustTransactions: Bool
        public var hidesDustBalances: Bool
    }

    public enum Event {
        case didUpdateIsSecureMode(isSecureMode: Bool)
        case didUpdateSearchEngine
        case didUpdateHistoryFilter
        case didUpdateBalanceFilter
    }

    private let keeperInfoStore: KeeperInfoStore

    override public func createInitialState() -> State {
        getState(keeperInfo: keeperInfoStore.getState())
    }

    init(keeperInfoStore: KeeperInfoStore) {
        self.keeperInfoStore = keeperInfoStore
        super.init(state: Self.defaultState)
    }

    public func toggleIsSecureMode(completion: ((State) -> Void)? = nil) {
        updateAppSettings(
            transform: { $0.updating(isSecureMode: !$0.isSecureMode) },
            makeEvent: { .didUpdateIsSecureMode(isSecureMode: $0.isSecureMode) },
            completion: completion
        )
    }

    public func setSearchEngine(
        _ searchEngine: SearchEngine,
        completion: ((State) -> Void)? = nil
    ) {
        updateAppSettings(
            transform: { $0.updating(searchEngine: searchEngine) },
            makeEvent: { _ in .didUpdateSearchEngine },
            completion: completion
        )
    }

    public func setHidesDustTransactions(_ hidesDustTransactions: Bool, completion: ((State) -> Void)? = nil) {
        updateAppSettings(
            transform: { $0.updating(hidesDustTransactions: hidesDustTransactions) },
            makeEvent: { _ in .didUpdateHistoryFilter },
            completion: completion
        )
    }

    public func setHidesDustBalances(_ hidesDustBalances: Bool, completion: ((State) -> Void)? = nil) {
        updateAppSettings(
            transform: { $0.updating(hidesDustBalances: hidesDustBalances) },
            makeEvent: { _ in .didUpdateBalanceFilter },
            completion: completion
        )
    }

    private func updateAppSettings(
        transform: @escaping (KeeperInfo.AppSettings) -> KeeperInfo.AppSettings,
        makeEvent: @escaping (State) -> Event,
        completion: ((State) -> Void)?
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo = keeperInfo else { return nil }
            return keeperInfo.updateAppSettings(transform(keeperInfo.appSettings))
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(makeEvent(state))
                completion?(state)
            }
        }
    }

    private static var defaultState: State {
        State(
            isSecureMode: false,
            searchEngine: .duckduckgo,
            hidesDustTransactions: false,
            hidesDustBalances: false
        )
    }

    private func getState(keeperInfo: KeeperInfo?) -> State {
        guard let keeperInfo = keeperInfoStore.state else {
            return Self.defaultState
        }
        return State(
            isSecureMode: keeperInfo.appSettings.isSecureMode,
            searchEngine: keeperInfo.appSettings.searchEngine,
            hidesDustTransactions: keeperInfo.appSettings.hidesDustTransactions,
            hidesDustBalances: keeperInfo.appSettings.hidesDustBalances
        )
    }
}
