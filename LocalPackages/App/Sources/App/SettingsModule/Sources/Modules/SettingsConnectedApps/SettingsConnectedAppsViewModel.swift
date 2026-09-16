import KeeperCore
import SwiftUI
import TKCore
import TKLocalize
import TKUIKit

final class SettingsConnectedAppsViewModel: ObservableObject {
    struct DApp: Identifiable, Equatable {
        struct ExtraInfo: Equatable {
            let source: String
            let date: String

            var cellExtraInfo: DAppCellContent.ExtraInfo {
                (source: source, date: date)
            }
        }

        var id: String
        var name: String
        var host: String
        var image: AssetAvatarViewImageSource
        var sourceAccent: Color?
        var extraInfo: ExtraInfo?

        init(
            id: String,
            name: String,
            host: String,
            image: AssetAvatarViewImageSource,
            sourceAccent: Color?,
            extraInfo: ExtraInfo?
        ) {
            self.id = id
            self.name = name
            self.host = host
            self.image = image
            self.sourceAccent = sourceAccent
            self.extraInfo = extraInfo
        }
    }

    enum State {
        case loading
        case loaded([DApp])
    }

    @Published private(set) var state: State = .loading

    var didRequestClose: (() -> Void)?
    var didRequestShowAlert: ((_ message: String) -> Void)?
    var didRequestShowDisconnectConfirmation: ((
        _ configuration: WalletConnectConfirmationPresenter.Configuration,
        _ disconnect: @escaping () -> Void
    ) -> Void)?

    var canDisconnectAllApps: Bool {
        displayedDApps.count > 1
    }

    private let wallet: Wallet
    private let connectedAppsStore: ConnectedAppsStore
    private let tonConnectConnectionMetadataStore: TonConnectConnectionMetadataStore
    private let walletConnectSessionsStore: WalletConnectSessionsStore?
    private let notificationsService: NotificationsService
    private let pushTokenProvider: PushNotificationTokenProvider
    private let dateFormatter: DateFormatter

    private var connectedApps = [ConnectedApp]()
    private var displayedDApps = [DApp]()
    private var disconnectTargetsByDAppId = [String: [ConnectedApp]]()
    private var tonConnectMetadataByClientId = [String: TonConnectConnectionMetadata]()
    private var didStart = false

    init(
        wallet: Wallet,
        connectedAppsStore: ConnectedAppsStore,
        tonConnectConnectionMetadataStore: TonConnectConnectionMetadataStore,
        walletConnectSessionsStore: WalletConnectSessionsStore?,
        notificationsService: NotificationsService,
        pushTokenProvider: PushNotificationTokenProvider,
        dateFormatter: DateFormatter
    ) {
        self.wallet = wallet
        self.connectedAppsStore = connectedAppsStore
        self.tonConnectConnectionMetadataStore = tonConnectConnectionMetadataStore
        self.walletConnectSessionsStore = walletConnectSessionsStore
        self.notificationsService = notificationsService
        self.pushTokenProvider = pushTokenProvider
        let connectedAppsDateFormatter = dateFormatter.copy() as? DateFormatter ?? DateFormatter()
        connectedAppsDateFormatter.dateFormat = "d MMM, HH:mm"
        self.dateFormatter = connectedAppsDateFormatter
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        connectedAppsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateApps:
                DispatchQueue.main.async {
                    observer.reload()
                }
            }
        }

        walletConnectSessionsStore?.addObserver(self) { observer, event in
            switch event {
            case .didUpdateSessions:
                DispatchQueue.main.async {
                    observer.reload()
                }
            case let .didFailDisconnect(message):
                DispatchQueue.main.async {
                    observer.didRequestShowAlert?(message)
                }
            }
        }

        reload()
        walletConnectSessionsStore?.refresh()
    }

    func close() {
        didRequestClose?()
    }

    func disconnect(dApp: DApp) {
        guard let disconnectTargets = disconnectTargetsByDAppId[dApp.id],
              let representativeApp = disconnectTargets.first
        else {
            return
        }

        didRequestShowDisconnectConfirmation?(
            .disconnectDApp(
                appName: representativeApp.name,
                iconURL: representativeApp.iconURL,
                disconnectButtonTitle: TKLocales.Settings.ConnectedApps.Actions.disconnect,
                cancelButtonTitle: TKLocales.Settings.ConnectedApps.Actions.cancel
            ),
            { [weak self] in
                self?.disconnect(apps: disconnectTargets)
            }
        )
    }

    func disconnectAllApps() {
        didRequestShowDisconnectConfirmation?(
            .disconnectAllApps(
                title: TKLocales.Settings.ConnectedApps.disconnectAllTitle,
                disconnectButtonTitle: TKLocales.Settings.ConnectedApps.Actions.disconnect,
                cancelButtonTitle: TKLocales.Settings.ConnectedApps.Actions.cancel
            ),
            { [weak self] in
                self?.disconnect(apps: self?.connectedApps ?? [])
            }
        )
    }
}

private struct ConnectedAppsPresentation {
    let dApps: [SettingsConnectedAppsViewModel.DApp]
    let disconnectTargetsByDAppId: [String: [ConnectedApp]]
}

private extension SettingsConnectedAppsViewModel {
    func reload() {
        let tonConnectMetadataByClientId = tonConnectConnectionMetadataStore.metadata(wallet: wallet)
        self.tonConnectMetadataByClientId = tonConnectMetadataByClientId

        let tonConnectApps = TonConnectConnectedAppsBuilder()
            .sessionConnections(
                from: connectedAppsStore.getState(),
                metadataProvider: { tonConnectMetadataByClientId[$0.clientId] }
            )
            .map(ConnectedApp.tonConnect)
        let walletConnectApps = (walletConnectSessionsStore.map {
            WalletConnectConnectedAppsBuilder().sessionConnections(
                from: $0.getState(),
                walletId: wallet.id
            )
        } ?? [])
            .map(ConnectedApp.walletConnect)

        let updatedConnectedApps = tonConnectApps + walletConnectApps
        let presentation = makePresentation(from: updatedConnectedApps)

        let update = {
            self.connectedApps = updatedConnectedApps
            self.displayedDApps = presentation.dApps
            self.disconnectTargetsByDAppId = presentation.disconnectTargetsByDAppId
            self.state = .loaded(presentation.dApps)
        }
        if case .loaded = state {
            withAnimation {
                update()
            }
        } else {
            update()
        }
    }

    func makePresentation(from apps: [ConnectedApp]) -> ConnectedAppsPresentation {
        var dApps = [DApp]()
        var disconnectTargetsByDAppId = [String: [ConnectedApp]]()
        var unknownSourceDAppIndexByKey = [String: Int]()

        for app in apps {
            let sourceState = sourceState(for: app)
            if sourceState.isUnknown {
                if let dAppIndex = unknownSourceDAppIndexByKey[app.dappKey] {
                    let dAppId = dApps[dAppIndex].id
                    disconnectTargetsByDAppId[dAppId, default: []].append(app)
                } else {
                    let dApp = makeDApp(for: app, sourceState: sourceState)
                    unknownSourceDAppIndexByKey[app.dappKey] = dApps.count
                    dApps.append(dApp)
                    disconnectTargetsByDAppId[dApp.id] = [app]
                }
            } else {
                let dApp = makeDApp(for: app, sourceState: sourceState)
                dApps.append(dApp)
                disconnectTargetsByDAppId[dApp.id] = [app]
            }
        }

        return ConnectedAppsPresentation(
            dApps: dApps,
            disconnectTargetsByDAppId: disconnectTargetsByDAppId
        )
    }

    func makeDApp(
        for app: ConnectedApp,
        sourceState: DappConnectionSourceState
    ) -> DApp {
        DApp(
            id: app.id,
            name: app.name,
            host: app.host,
            image: image(for: app, sourceState: sourceState),
            sourceAccent: sourceAccent(for: sourceState),
            extraInfo: extraInfo(for: sourceState)
        )
    }

    func image(
        for app: ConnectedApp,
        sourceState: DappConnectionSourceState
    ) -> AssetAvatarViewImageSource {
        .url(app.iconURL, chainIcon: sourceState.extraInfo?.source.dAppCellChainIcon)
    }

    func sourceAccent(for sourceState: DappConnectionSourceState) -> Color? {
        sourceState.extraInfo?.source.dAppCellChainIconAccent.map(Color.init(uiColor:))
    }

    func extraInfo(for sourceState: DappConnectionSourceState) -> DApp.ExtraInfo? {
        guard let extraInfo = sourceState.extraInfo else {
            return nil
        }

        return DApp.ExtraInfo(
            source: extraInfo.source.dAppCellTitle,
            date: dateFormatter.string(from: extraInfo.createdAt)
        )
    }

    func sourceState(for app: ConnectedApp) -> DappConnectionSourceState {
        switch app {
        case let .tonConnect(connection):
            return tonConnectMetadataByClientId[connection.clientId]?.sourceState ?? .unknown
        case let .walletConnect(connection):
            return connection.sourceState
        }
    }

    func disconnect(apps: [ConnectedApp]) {
        let tonConnectApps = apps.compactMap(\.tonConnectApp)
        tonConnectApps.forEach(connectedAppsStore.deleteAppSession)

        walletConnectSessionsStore?.disconnect(
            topics: apps.compactMap(\.walletConnectConnection).flatMap(\.topics)
        )

        turnOffDappNotifications(for: tonConnectApps)
    }

    func turnOffDappNotifications(for apps: [TonConnectApp]) {
        guard !apps.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            guard let token = await self.pushTokenProvider.getToken() else { return }
            for app in apps {
                _ = try? await self.notificationsService.turnOffDappNotifications(
                    wallet: self.wallet,
                    manifest: app.manifest,
                    sessionId: app.clientId,
                    token: token
                )
            }
        }
    }
}

private extension DappConnectionSource {
    var dAppCellTitle: String {
        switch self {
        case .qr:
            return TKLocales.Settings.ConnectedApps.Source.qr
        case .dapp:
            return TKLocales.Settings.ConnectedApps.Source.dapp
        case .browser:
            return TKLocales.Settings.ConnectedApps.Source.browser
        case .deeplink:
            return TKLocales.Settings.ConnectedApps.Source.deeplink
        }
    }

    var dAppCellChainIcon: UIImage? {
        switch self {
        case .qr:
            return .TKUIKit.Icons.Size20.qrCodeSmall
        case .dapp:
            return BrandMarks.small
        case .deeplink, .browser:
            return .TKUIKit.Icons.Size20.linkSmall
        }
    }

    var dAppCellChainIconAccent: UIColor? {
        switch self {
        case .qr:
            return .Accent.green
        case .dapp:
            return .Accent.blue
        case .deeplink, .browser:
            return .Accent.purple
        }
    }
}
