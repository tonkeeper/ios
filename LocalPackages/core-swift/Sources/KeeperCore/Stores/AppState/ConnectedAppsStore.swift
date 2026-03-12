import Foundation

public final class ConnectedAppsStore: Store<ConnectedAppsStore.Event, [TonConnectApp]> {
    public enum Event {
        case didUpdateApps
    }

    private let walletsStore: WalletsStore
    private let tonConnectAppsStore: TonConnectAppsStore

    public init(
        walletsStore: WalletsStore,
        tonConnectAppsStore: TonConnectAppsStore
    ) {
        self.walletsStore = walletsStore
        self.tonConnectAppsStore = tonConnectAppsStore

        super.init(state: [])

        bindDependencies()
    }

    override public func createInitialState() -> [TonConnectApp] {
        calculateState()
    }

    private func bindDependencies() {
        tonConnectAppsStore.addObserver(self)
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case .didChangeActiveWallet:
                observer.update()
            default:
                break
            }
        }
    }

    private func calculateState() -> [TonConnectApp] {
        do {
            return try tonConnectAppsStore.connectedApps(forWallet: walletsStore.activeWallet)
                .apps
        } catch {
            return []
        }
    }

    public func deleteApp(_ app: TonConnectApp) {
        guard let wallet = try? walletsStore.activeWallet else {
            return
        }

        tonConnectAppsStore.deleteConnectedApp(wallet: wallet, app: app)
        update()
    }

    private func update() {
        updateState { [weak self] _ in
            guard let self else {
                return nil
            }
            return StateUpdate(newState: calculateState())
        } completion: { [weak self] _ in
            guard let self else {
                return
            }
            sendEvent(.didUpdateApps)
        }
    }
}

// MARK: -  TonConnectAppsStoreObserver

extension ConnectedAppsStore: TonConnectAppsStoreObserver {
    public func didGetTonConnectAppsStoreEvent(_ event: TonConnectAppsStoreEvent) {
        update()
    }
}
