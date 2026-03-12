import Foundation
import TKLocalize
import TKLogging
import TonSwift

public final class WalletInfoLoader {
    private var loadTask: Task<Void, Never>?
    private let walletsStore: WalletsStore
    private let walletService: WalletService
    private let internalNotificationsStore: InternalNotificationsStore

    init(
        walletsStore: WalletsStore,
        walletService: WalletService,
        internalNotificationsStore: InternalNotificationsStore
    ) {
        self.walletsStore = walletsStore
        self.walletService = walletService
        self.internalNotificationsStore = internalNotificationsStore

        setupObservations()
    }

    public func loadActiveWalletInfoNotifications() {
        loadTask?.cancel()
        loadTask = Task { [walletsStore, walletService, internalNotificationsStore] in
            do {
                let activeWallet = try walletsStore.activeWallet

                let notificationId: String = .notificationIdPrefix + activeWallet.id

                let info = try await walletService.loadWallet(network: activeWallet.network, address: activeWallet.address)

                try Task.checkCancellation()

                let subscriptionPluginsCount = info.plugins.count {
                    $0.status == .active && $0.type == "subscription_v1"
                }

                if subscriptionPluginsCount == 0 {
                    await internalNotificationsStore.removeNotificationById(notificationId, persistant: false)
                    return
                }

                let notification = NotificationModel(
                    id: notificationId,
                    title: TKLocales.SubscriptionPluginWarning.titlePluralized(count: subscriptionPluginsCount),
                    caption: subscriptionPluginsCount == 1 ? TKLocales.SubscriptionPluginWarning.captionOne : TKLocales.SubscriptionPluginWarning.captionMany,
                    mode: .warning,
                    action: NotificationModel.Action(
                        type: .openLink(URL(string: "https://wallet.tonkeeper.com")),
                        label: TKLocales.SubscriptionPluginWarning.button
                    )
                )

                await internalNotificationsStore.addNotification(notification)

            } catch is CancellationError {}
            catch {
                Log.w("Failed loadActiveWalletInfoNotifications, error: \(error.localizedDescription)")
            }
        }
    }

    private func setupObservations() {
        walletsStore.addObserver(self) { observer, event in
            DispatchQueue.main.async {
                switch event {
                case let .didChangeActiveWallet(from, _):
                    Task {
                        let notificationId: String = .notificationIdPrefix + from.id
                        await self.internalNotificationsStore.removeNotificationById(notificationId, persistant: false)
                    }

                    observer.loadActiveWalletInfoNotifications()
                default: break
                }
            }
        }
    }
}

private extension String {
    static let notificationIdPrefix = "active_v1_subscriptions_"
}
