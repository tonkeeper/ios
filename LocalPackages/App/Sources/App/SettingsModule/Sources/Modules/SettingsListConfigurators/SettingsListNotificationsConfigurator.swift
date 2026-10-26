import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit
import UserNotifications

final class SettingsListNotificationsConfigurator: SettingsListConfigurator {
    // MARK: - SettingsListConfigurator

    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        TKLocales.Settings.Notifications.title
    }

    func getInitialState() -> SettingsListState {
        updateIsPushAvailable()
        return createState()
    }

    // MARK: - State

    private var isPushAvailable = true {
        didSet {
            didUpdateIsPushAvailable()
        }
    }

    private var notificationToken: NSObjectProtocol?

    private let dappToggleSync = CoalescingToggleSync<String>()

    // MARK: - Dependencies

    private let wallet: Wallet
    private let walletNotificationStore: WalletNotificationStore
    private let notificationsService: NotificationsService
    private let tonConnectAppsStore: TonConnectAppsStore
    private let urlOpener: URLOpener
    private let pushTokenProvider: PushNotificationTokenProvider
    private let appSettings: AppSettings

    // MARK: - Init

    init(
        wallet: Wallet,
        walletNotificationStore: WalletNotificationStore,
        notificationsService: NotificationsService,
        tonConnectAppsStore: TonConnectAppsStore,
        urlOpener: URLOpener,
        pushTokenProvider: PushNotificationTokenProvider,
        appSettings: AppSettings
    ) {
        self.wallet = wallet
        self.walletNotificationStore = walletNotificationStore
        self.notificationsService = notificationsService
        self.tonConnectAppsStore = tonConnectAppsStore
        self.urlOpener = urlOpener
        self.pushTokenProvider = pushTokenProvider
        self.appSettings = appSettings

        notificationToken = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.updateIsPushAvailable()
        })

        tonConnectAppsStore.addObserver(self)

        walletNotificationStore.addObserver(self) { observer, _ in
            DispatchQueue.main.async {
                let state = observer.createState()
                observer.didUpdateState?(state)
            }
        }
    }

    deinit {
        notificationToken = nil
    }

    private func createState() -> SettingsListState {
        let notificationsState = walletNotificationStore.getState()[wallet]
        var sections = [SettingsListSection]()
        if !isPushAvailable {
            sections.append(createNotificationsNotAvailableSection())
        }
        sections.append(createPushNotificationsSection())
        if let connectedAppsSection = createConnectedAppsSection(notificationsState: notificationsState) {
            sections.append(connectedAppsSection)
        }
        return SettingsListState(sections: sections)
    }

    private func didUpdateIsPushAvailable() {
        let state = createState()
        didUpdateState?(state)
    }

    private func createPushNotificationsSection() -> SettingsListSection {
        .items(SettingsListItemsSection(
            items: [.listItem(createPushNotificationsItem())]
        ))
    }

    private func createNotificationsNotAvailableSection() -> SettingsListSection {
        .items(SettingsListItemsSection(
            items: [.banner(createNotificationsNotAvailableItem())]
        ))
    }

    private func createPushNotificationsItem() -> SettingsListItem {
        let isOn: Bool = {
            guard let isOn = walletNotificationStore.getState()[wallet]?.isOn else { return false }
            return isOn
        }()

        let action: (Bool) -> Void = { [weak self] isOn in
            guard let self else { return }

            Task {
                await self.walletNotificationStore.setNotificationIsOn(isOn, wallet: self.wallet)
            }
        }

        return SettingsListItem(
            id: .walletNotificationsIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Notifications.NotificationsItem.title),
            captions: [SettingsListItemCaption(TKLocales.Settings.Notifications.NotificationsItem.caption)],
            accessory: .toggle(
                SettingsListItemToggleAccessory(
                    isOn: isOn,
                    isEnabled: isPushAvailable,
                    onToggle: action
                )
            )
        )
    }

    private func createNotificationsNotAvailableItem() -> SettingsListBannerItem {
        SettingsListBannerItem(
            id: .notificationsNotAvailableBannerIdentifier,
            content: NotificationBannerContent(
                title: TKLocales.Settings.Notifications.NotificationsDisabled.title,
                description: TKLocales.Settings.Notifications.NotificationsDisabled.caption,
                state: .accentOrange,
                buttonTitle: TKLocales.Settings.Notifications.NotificationsDisabled.actionTitle
            ),
            onButtonTap: { [urlOpener] in
                guard let url = URL(string: UIApplication.openSettingsURLString),
                      urlOpener.canOpen(url: url)
                else {
                    return
                }
                urlOpener.open(url: url)
            }
        )
    }

    private func createConnectedAppsSection(notificationsState: WalletNotificationStore.NotificationsState?) -> SettingsListSection? {
        let apps = (try? tonConnectAppsStore.connectedApps(forWallet: wallet).apps.unique) ?? []
        guard !apps.isEmpty else { return nil }
        let items = apps.map { app in
            let isOn = notificationsState?.dapps.first(where: { $0.key == app.manifest.host })?.value ?? false
            return createConnectedAppItem(app, isOn: isOn)
        }
        return .items(SettingsListItemsSection(
            items: items.map(SettingsListItemsSectionItem.listItem),
            header: SettingsListSectionHeader(
                title: .connectedAppsSectionTitle,
                caption: .connectedAppsSectionCaption
            )
        ))
    }

    private func createConnectedAppItem(_ app: TonConnectApp, isOn: Bool) -> SettingsListItem {
        SettingsListItem(
            id: app.manifest.host,
            icon: .url(app.manifest.iconUrl),
            title: SettingsListItemTitle(app.manifest.name),
            accessory: .toggle(
                SettingsListItemToggleAccessory(
                    isOn: isOn,
                    isEnabled: isOn || isPushAvailable,
                    onToggle: { [weak self] isOn in
                        self?.setDappNotificationsIsOn(isOn, app: app)
                    }
                )
            )
        )
    }

    private func setDappNotificationsIsOn(_ isOn: Bool, app: TonConnectApp) {
        let host = app.manifest.host
        let store = walletNotificationStore
        let wallet = wallet
        // Keep sync alive after the screen closes so rollback can finish.
        _ = MainActor.assumeIsolated {
            dappToggleSync.toggle(
                isOn,
                key: host,
                currentIsOn: store.getState()[wallet]?.dapps[host] ?? false,
                apply: { value in
                    await store.setNotificationsIsOn(value, wallet: wallet, dappHost: host)
                },
                sync: { [self] value, accepted in
                    if value {
                        guard await ensurePushAuthorized() else { return false }
                    }
                    guard let token = await resolvePushToken(),
                          await syncDappNotifications(value, acceptedIsOn: accepted, app: app, token: token)
                    else {
                        ToastPresenter.showToast(configuration: .failed)
                        return false
                    }
                    return true
                },
                onRejected: { [self] in
                    guard let token = await resolvePushToken() else { return }
                    _ = await notificationsService.syncDappNotifications(wallet: wallet, host: host, token: token)
                }
            )
        }
    }

    private func resolvePushToken() async -> String? {
        guard let token = await pushTokenProvider.getToken() else {
            return appSettings.fcmToken
        }
        appSettings.fcmToken = token
        return token
    }

    private func syncDappNotifications(_ isOn: Bool, acceptedIsOn: Bool, app: TonConnectApp, token: String) async -> Bool {
        await(try? notificationsService.setDappNotifications(
            isOn: isOn,
            previousIsOn: acceptedIsOn,
            wallet: wallet,
            manifest: app.manifest,
            token: token
        )) ?? false
    }

    /// Avoid an enabled toggle when push delivery is not authorized.
    private func ensurePushAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .notDetermined else {
            guard status.isPushAuthorized else { return false }
            // A Settings grant may leave APNs unregistered.
            await UIApplication.shared.registerForRemoteNotifications()
            return true
        }
        let isGranted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if isGranted {
            await UIApplication.shared.registerForRemoteNotifications()
        }
        // Answering the prompt is not a foreground transition, so the observer above does not run.
        updateIsPushAvailable()
        return isGranted
    }

    private func updateIsPushAvailable() {
        Task {
            let status = await UNUserNotificationCenter.current()
                .notificationSettings()
                .authorizationStatus
            if status.isPushAuthorized {
                // Register before the next toggle needs an FCM token.
                await UIApplication.shared.registerForRemoteNotifications()
            }
            await MainActor.run {
                self.isPushAvailable = status.isPushAuthorized || status == .notDetermined
            }
        }
    }
}

extension SettingsListNotificationsConfigurator: TonConnectAppsStoreObserver {
    func didGetTonConnectAppsStoreEvent(_ event: KeeperCore.TonConnectAppsStoreEvent) {
        DispatchQueue.main.async {
            let state = self.createState()
            self.didUpdateState?(state)
        }
    }
}

private extension String {
    static let walletNotificationsIdentifier = "WalletNotificationsIdentifier"
    static let notificationsNotAvailableBannerIdentifier = "NotificationsNotAvailableBannerIdentifier"
    static let connectedAppsSectionTitle = TKLocales.SettingsListNotificationsConfigurator.connectedAppsTitle
    static let connectedAppsSectionCaption = TKLocales.SettingsListNotificationsConfigurator.connectedAppsSectionCaption
}
