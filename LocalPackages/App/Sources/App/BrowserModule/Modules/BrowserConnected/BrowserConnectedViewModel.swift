import DisconnectDappToast
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol BrowserConnectedModuleOutput: AnyObject {
    var didSelectDapp: ((Dapp) -> Void)? { get set }
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

    var didSelectDapp: ((Dapp) -> Void)?

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
    }

    func selectApp(index: Int) {
        guard connectedApps.count > index else { return }
        let connectedApp = connectedApps[index]
        let dapp = Dapp(
            name: connectedApp.manifest.name,
            description: nil,
            icon: connectedApp.manifest.iconUrl,
            poster: nil,
            url: connectedApp.manifest.url,
            textColor: nil,
            excludeCountries: nil,
            includeCountries: nil
        )
        didSelectDapp?(dapp)
        analyticsProvider.logClickDappEvent(
            name: dapp.name,
            url: dapp.url.absoluteString,
            from: .browserConnected
        )
    }

    // MARK: - State

    private var connectedApps = [TonConnectApp]() {
        didSet {
            DispatchQueue.main.async {
                self.didUpdateConnectedApps()
            }
        }
    }

    // MARK: - Image Loading

    private let imageLoader = ImageLoader()

    // MARK: - Dependencies

    private let walletsStore: WalletsStore
    private let connectedAppsStore: ConnectedAppsStore
    private let notificationsService: NotificationsService
    private let pushTokenProvider: PushNotificationTokenProvider
    private let analyticsProvider: AnalyticsProvider

    // MARK: - Init

    init(
        walletsStore: WalletsStore,
        connectedAppsStore: ConnectedAppsStore,
        notificationsService: NotificationsService,
        pushTokenProvider: PushNotificationTokenProvider,
        analyticsProvider: AnalyticsProvider
    ) {
        self.walletsStore = walletsStore
        self.connectedAppsStore = connectedAppsStore
        self.notificationsService = notificationsService
        self.pushTokenProvider = pushTokenProvider
        self.analyticsProvider = analyticsProvider
    }
}

private extension BrowserConnectedViewModelImplementation {
    func reloadContent() {
        connectedApps = connectedAppsStore.getState().unique
    }

    func updateSnapshot(sections: [BrowserConnected.Section]) {
        var snapshot = BrowserConnected.Snapshot()
        for section in sections {
            switch section {
            case .apps:
                let items = connectedApps.compactMap { app in
                    let configuration = BrowserAppCollectionViewCell.Configuration(
                        id: UUID().uuidString,
                        title: app.manifest.name,
                        isTwoLinesTitle: false,
                        iconModel: TKImageView.Model(
                            image: .urlImage(app.manifest.iconUrl),
                            size: .size(CGSize(width: 64, height: 64)),
                            corners: .cornerRadius(cornerRadius: 16)
                        )
                    )

                    return BrowserConnected.Item(
                        identifier: UUID().uuidString,
                        title: app.manifest.name,
                        configuration: configuration,
                        longPressHandler: { [weak self] in
                            let model = DisconnectDappToastModel(
                                title: "\(TKLocales.Dapp.DisconnectToast.title) \"\(app.manifest.name)\"?",
                                buttonTitle: TKLocales.Dapp.DisconnectToast.button,
                                buttonAction: { [weak self] in
                                    self?.connectedAppsStore.deleteApp(app)
                                    Task { [weak self] in
                                        guard let self else { return }
                                        guard let token = await self.pushTokenProvider.getToken(),
                                              let wallet = try? walletsStore.activeWallet else { return }
                                        _ = try? await notificationsService.turnOffDappNotifications(
                                            wallet: wallet,
                                            manifest: app.manifest,
                                            sessionId: app.clientId,
                                            token: token
                                        )
                                    }
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
