import KeeperCore
import TKCore
import TKLogging
import TonSwift
import UIKit
import UserNotifications

final class PushNotificationManager {
    private var deferedActions = [(String) -> Void]()

    private let queue = DispatchQueue(label: "PushNotificationManagerQueue", qos: .userInitiated)
    private var notificationsUpdateTask = [Wallet: Task<Void, Never>]()
    private var dappTasks = [String: Task<Void, Never>]()

    private let appSettings: AppSettings
    private let uniqueIdProvider: UniqueIdProvider
    private let pushNotificationTokenProvider: PushNotificationTokenProvider
    private let pushNotificationAPI: PushNotificationsAPI
    private let walletNotificationsStore: WalletNotificationStore
    private let tonConnectAppsStore: TonConnectAppsStore
    private let tonProofTokenService: TonProofTokenService

    init(
        appSettings: AppSettings,
        uniqueIdProvider: UniqueIdProvider,
        pushNotificationTokenProvider: PushNotificationTokenProvider,
        pushNotificationAPI: PushNotificationsAPI,
        walletNotificationsStore: WalletNotificationStore,
        tonConnectAppsStore: TonConnectAppsStore,
        tonProofTokenService: TonProofTokenService
    ) {
        self.appSettings = appSettings
        self.uniqueIdProvider = uniqueIdProvider
        self.pushNotificationTokenProvider = pushNotificationTokenProvider
        self.pushNotificationAPI = pushNotificationAPI
        self.walletNotificationsStore = walletNotificationsStore
        self.tonConnectAppsStore = tonConnectAppsStore
        self.tonProofTokenService = tonProofTokenService
    }

    func setup() {
        pushNotificationTokenProvider.setup()
        walletNotificationsStore.addObserver(self) { observer, event in
            observer.queue.async {
                observer.didGetNotificationsStoreEvent(event)
            }
        }

        pushNotificationTokenProvider.didUpdateToken = { [appSettings] token in
            guard appSettings.fcmToken != token else {
                return
            }
            appSettings.fcmToken = token
            // resubscribe all wallets
        }
        Task {
            await registerForPushNotificationsIfNeeded()
        }
    }

    private func registerForPushNotificationsIfNeeded() async {
        let notificationCenter = UNUserNotificationCenter.current()
        switch await notificationCenter.notificationSettings().authorizationStatus {
        case .authorized:
            await registerForPushNotifications()
        default:
            break
        }
    }

    private func registerForPushNotifications() async {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions) else {
                return
            }
            await UIApplication.shared.registerForRemoteNotifications()
        } catch {
            Log.w("Log 🪵: PushNotificationManager - failed to register for remote notifications")
        }
    }

    private func didGetNotificationsStoreEvent(_ event: WalletNotificationStore.Event) {
        switch event {
        case let .didUpdateNotificationsIsOn(wallet):
            notificationsUpdateTask[wallet]?.cancel()
            let isOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false
            if isOn {
                subscribePushNotifications(wallet: wallet)
            } else {
                unsubscribePushNotifications(wallet: wallet)
            }
        case .didUpdateDappNotificationsIsOn:
            break
        }
    }

    private func subscribePushNotifications(wallet: Wallet) {
        let action: (String) -> Void = { [uniqueIdProvider, pushNotificationAPI] token in
            Task {
                _ = try await pushNotificationAPI.subscribeNotifications(
                    subscribeData: PushNotificationsAPI.SubscribeData(
                        token: token,
                        device: uniqueIdProvider.uniqueDeviceId.uuidString,
                        accounts: [PushNotificationsAPI.SubscribeData.Account(address: wallet.friendlyAddress.toString())],
                        locale: Locale.current.languageCode ?? "en"
                    )
                )
            }
        }

        let task = Task {
            switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
            case .authorized:
                break
            default:
                await registerForPushNotifications()
            }
            guard let token = await pushNotificationTokenProvider.getToken() else {
                await MainActor.run {
                    deferedActions.append(action)
                }
                return
            }

            action(token)
        }
        notificationsUpdateTask[wallet] = task
    }

    private func unsubscribePushNotifications(wallet: Wallet) {
        let action: (String) -> Void = { [uniqueIdProvider, pushNotificationAPI] _ in
            Task {
                _ = try await pushNotificationAPI.unsubscribeNotifications(
                    unsubscribeData: PushNotificationsAPI.UnsubscribeData(
                        device: uniqueIdProvider.uniqueDeviceId.uuidString,
                        accounts: [PushNotificationsAPI.UnsubscribeData.Account(address: wallet.friendlyAddress.toString())]
                    )
                )
            }
        }

        let task = Task {
            guard let token = await pushNotificationTokenProvider.getToken() else {
                await MainActor.run {
                    deferedActions.append(action)
                }
                return
            }

            action(token)
        }
        notificationsUpdateTask[wallet] = task
    }
}
