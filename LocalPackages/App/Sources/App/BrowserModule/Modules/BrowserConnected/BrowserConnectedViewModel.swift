import AppUI
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
protocol BrowserConnectedModuleOutput: AnyObject {
    var didSelectDapp: ((DappOpenIntent) -> Void)? { get set }
}

protocol BrowserConnectedViewModel: AnyObject {
    var didUpdateViewState: ((BrowserConnectedViewController.State) -> Void)? { get set }
    var didUpdateSnapshot: ((BrowserConnected.Snapshot) -> Void)? { get set }
    var didUpdateFeaturedItems: (([Dapp]) -> Void)? { get set }
    var presentDisconnectAppToast: ((DisconnectDappToastModel) -> Void)? { get set }

    func viewDidLoad()
    func selectApp(index: Int)
}

final class BrowserConnectedViewModelImplementation: BrowserConnectedViewModel, BrowserConnectedModuleOutput {
    // MARK: - BrowserConnectedModuleOutput

    var didSelectDapp: ((DappOpenIntent) -> Void)?

    // MARK: - BrowserConnectedViewModel

    var didUpdateViewState: ((BrowserConnectedViewController.State) -> Void)?
    var didUpdateSnapshot: ((BrowserConnected.Snapshot) -> Void)?
    var didUpdateFeaturedItems: (([Dapp]) -> Void)?
    var presentDisconnectAppToast: ((DisconnectDappToastModel) -> Void)?

    func viewDidLoad() {
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

    func selectApp(index: Int) {
        guard connectedApps.count > index else { return }
        let connectedApp = connectedApps[index]
        guard let dapp = connectedApp.dapp else {
            return
        }
        didSelectDapp?(.dapp(source: .browserConnected, dapp: dapp))
    }

    // MARK: - State

    private var connectedApps = [ConnectedApp]() {
        didSet {
            DispatchQueue.main.async {
                self.didUpdateConnectedApps()
            }
        }
    }

    private var walletConnectSessionsStore: WalletConnectSessionsStore?
    private var walletConnectSessionsStoreTask: Task<Void, Never>?

    // MARK: - Image Loading

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

private extension BrowserConnectedViewModelImplementation {
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

        Task { [weak self] in
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

    func updateSnapshot(sections: [BrowserConnected.Section]) {
        var snapshot = BrowserConnected.Snapshot()
        for section in sections {
            switch section {
            case .apps:
                let items = connectedApps.compactMap { app in
                    let configuration = BrowserAppCollectionViewCell.Configuration(
                        id: UUID().uuidString,
                        title: app.name,
                        isTwoLinesTitle: false,
                        iconModel: TKImageView.Model(
                            image: .urlImage(app.iconURL),
                            size: .size(CGSize(width: 64, height: 64)),
                            corners: .cornerRadius(cornerRadius: 16)
                        )
                    )

                    return BrowserConnected.Item(
                        identifier: UUID().uuidString,
                        title: app.name,
                        configuration: configuration,
                        longPressHandler: { [weak self] in
                            let model = DisconnectDappToastModel(
                                title: "\(TKLocales.Dapp.DisconnectToast.title) \"\(app.name)\"?",
                                buttonTitle: TKLocales.Dapp.DisconnectToast.button,
                                buttonAction: { [weak self] in
                                    self?.disconnect(app: app)
                                }
                            )

                            self?.presentDisconnectAppToast?(model)
                        }
                    )
                }

                snapshot.appendSections([.apps])
                snapshot.appendItems(items, toSection: .apps)
            }
        }

        didUpdateSnapshot?(snapshot)
    }

    func didUpdateConnectedApps() {
        let state: BrowserConnectedViewController.State
        let sections: [BrowserConnected.Section]

        defer {
            DispatchQueue.main.async {
                self.updateSnapshot(sections: sections)
                self.didUpdateViewState?(state)
            }
        }

        guard !connectedApps.isEmpty else {
            sections = []
            state = .empty(
                TKEmptyViewController.Model(
                    title: TKLocales.Browser.ConnectedApps.emptyTitle,
                    caption: TKLocales.Browser.ConnectedApps.emptyDescription,
                    buttons: []
                )
            )

            return
        }

        sections = [.apps]
        state = .data
    }
}
