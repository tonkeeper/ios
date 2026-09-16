import AppUI
import Combine
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

struct BrowserConnectedAppItem: Identifiable {
    var id: String
    var app: ConnectedApp
    var name: String
    var iconURL: URL?
    var chain: MultichainChain?
}

@MainActor
final class BrowserConnectedMultichainViewModelImplementation: ObservableObject, BrowserConnectedModuleOutput {
    enum ViewState {
        case loading
        case data([BrowserConnectedAppItem])
        case empty(title: String, caption: String)
    }

    // MARK: - BrowserConnectedModuleOutput

    var didSelectDapp: ((DappOpenIntent) -> Void)?

    // MARK: - BrowserConnectedViewModel

    @Published private(set) var viewState: ViewState = .loading
    var presentDisconnectAppToast: ((DisconnectDappToastModel) -> Void)?

    func viewDidLoad() {
        guard !didStart else { return }
        didStart = true

        connectedAppsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateApps:
                DispatchQueue.main.async {
                    observer.reloadContent()
                }
            }
        }

        reloadContent()
        loadWalletConnectSessionsStore()
    }

    func selectApp(_ item: BrowserConnectedAppItem) {
        guard let dapp = item.app.dapp else {
            return
        }
        didSelectDapp?(.dapp(source: .browserConnected, dapp: dapp))
    }

    func requestDisconnect(_ item: BrowserConnectedAppItem) {
        let model = DisconnectDappToastModel(
            title: "\(TKLocales.Dapp.DisconnectToast.title) \"\(item.name)\"?",
            buttonTitle: TKLocales.Dapp.DisconnectToast.button,
            buttonAction: { [weak self] in
                Task { @MainActor in
                    self?.disconnect(app: item.app)
                }
            }
        )

        presentDisconnectAppToast?(model)
    }

    // MARK: - State

    private var connectedApps = [ConnectedApp]() {
        didSet {
            didUpdateConnectedApps()
        }
    }

    private var didStart = false
    private var walletConnectSessionsStore: WalletConnectSessionsStore?
    private var walletConnectSessionsStoreTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let walletsStore: WalletsStore
    private let connectedAppsStore: ConnectedAppsStore
    private let tonConnectConnectionMetadataStore: TonConnectConnectionMetadataStore
    private let walletConnectSessionsStoreProvider: () async -> WalletConnectSessionsStore?
    private let notificationsService: NotificationsService
    private let pushTokenProvider: PushNotificationTokenProvider

    // MARK: - Init

    init(
        walletsStore: WalletsStore,
        connectedAppsStore: ConnectedAppsStore,
        tonConnectConnectionMetadataStore: TonConnectConnectionMetadataStore,
        walletConnectSessionsStoreProvider: @escaping () async -> WalletConnectSessionsStore?,
        notificationsService: NotificationsService,
        pushTokenProvider: PushNotificationTokenProvider
    ) {
        self.walletsStore = walletsStore
        self.connectedAppsStore = connectedAppsStore
        self.tonConnectConnectionMetadataStore = tonConnectConnectionMetadataStore
        self.walletConnectSessionsStoreProvider = walletConnectSessionsStoreProvider
        self.notificationsService = notificationsService
        self.pushTokenProvider = pushTokenProvider
    }

    deinit {
        walletConnectSessionsStoreTask?.cancel()
    }
}

private extension BrowserConnectedMultichainViewModelImplementation {
    func reloadContent() {
        guard let wallet = try? walletsStore.activeWallet else {
            connectedApps = []
            return
        }

        let tonConnectMetadataByClientId = tonConnectConnectionMetadataStore.metadata(wallet: wallet)
        let tonConnectApps = TonConnectConnectedAppsBuilder()
            .connections(
                from: connectedAppsStore.getState(),
                metadataProvider: { tonConnectMetadataByClientId[$0.clientId] },
                sourceFilter: isBrowserConnectedSourceState
            )
            .map(ConnectedApp.tonConnect)
        let walletConnectApps = walletConnectConnectedApps()
            .map(ConnectedApp.walletConnect)

        connectedApps = (tonConnectApps + walletConnectApps).uniqueDapps()
    }

    func loadWalletConnectSessionsStore() {
        guard walletConnectSessionsStoreTask == nil else {
            return
        }

        walletConnectSessionsStoreTask = Task { @MainActor [weak self] in
            guard let walletConnectSessionsStoreProvider = self?.walletConnectSessionsStoreProvider else {
                return
            }
            guard let walletConnectSessionsStore = await walletConnectSessionsStoreProvider() else {
                return
            }
            guard let self else { return }

            self.walletConnectSessionsStore = walletConnectSessionsStore
            self.setupWalletConnectSessionsStoreBindings(walletConnectSessionsStore)
            walletConnectSessionsStore.refresh()
            self.reloadContent()
        }
    }

    func setupWalletConnectSessionsStoreBindings(_ walletConnectSessionsStore: WalletConnectSessionsStore) {
        walletConnectSessionsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateSessions:
                DispatchQueue.main.async {
                    observer.reloadContent()
                }
            case .didFailDisconnect:
                break
            }
        }
    }

    func walletConnectConnectedApps() -> [WalletConnectDappConnection] {
        guard let walletConnectSessionsStore else {
            return []
        }
        guard let wallet = try? walletsStore.activeWallet else {
            return []
        }

        return WalletConnectConnectedAppsBuilder().connections(
            from: walletConnectSessionsStore.getState(),
            walletId: wallet.id,
            sourceFilter: isBrowserConnectedSourceState
        )
    }

    func disconnect(app: ConnectedApp) {
        let apps = tonConnectDisconnectTargets(matching: app) + walletConnectDisconnectTargets(matching: app)
        disconnect(apps: apps)
    }

    func disconnect(apps: [ConnectedApp]) {
        let tonConnectApps = apps.compactMap(\.tonConnectApp)
        tonConnectApps.forEach(connectedAppsStore.deleteAppSession)

        walletConnectSessionsStore?.disconnect(
            topics: apps.compactMap(\.walletConnectConnection).flatMap(\.topics)
        )

        turnOffDappNotifications(for: tonConnectApps)
    }

    func tonConnectDisconnectTargets(matching app: ConnectedApp) -> [ConnectedApp] {
        guard let wallet = try? walletsStore.activeWallet else {
            return []
        }

        let tonConnectMetadataByClientId = tonConnectConnectionMetadataStore.metadata(wallet: wallet)
        return connectedAppsStore.getState()
            .filter {
                ConnectedApp.tonConnect($0).isSameDapp(as: app)
                    && isBrowserConnectedSourceState(tonConnectMetadataByClientId[$0.clientId]?.sourceState ?? .unknown)
            }
            .map(ConnectedApp.tonConnect)
    }

    func walletConnectDisconnectTargets(matching app: ConnectedApp) -> [ConnectedApp] {
        walletConnectConnectedApps()
            .filter { ConnectedApp.walletConnect($0).isSameDapp(as: app) }
            .map(ConnectedApp.walletConnect)
    }

    func turnOffDappNotifications(for apps: [TonConnectApp]) {
        guard !apps.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let token = await self.pushTokenProvider.getToken(),
                  let wallet = try? self.walletsStore.activeWallet else { return }
            for app in apps {
                _ = try? await self.notificationsService.turnOffDappNotifications(
                    wallet: wallet,
                    manifest: app.manifest,
                    sessionId: app.clientId,
                    token: token
                )
            }
        }
    }

    func isBrowserConnectedSourceState(_ sourceState: DappConnectionSourceState) -> Bool {
        switch sourceState {
        case let .known(extraInfo):
            return extraInfo.source == .dapp
        case .unknown:
            return true
        }
    }

    func didUpdateConnectedApps() {
        guard !connectedApps.isEmpty else {
            viewState = .empty(
                title: TKLocales.Browser.ConnectedApps.emptyTitle,
                caption: TKLocales.Browser.ConnectedApps.emptyDescription
            )
            return
        }

        let items = connectedApps.map { app in
            BrowserConnectedAppItem(
                id: app.id,
                app: app,
                name: app.name,
                iconURL: app.iconURL,
                chain: app.chain
            )
        }
        viewState = .data(items)
    }
}
