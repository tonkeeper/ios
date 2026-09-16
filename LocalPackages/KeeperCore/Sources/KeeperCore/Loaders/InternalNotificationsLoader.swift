import Foundation
import TKLogging

final class InternalNotificationsLoader {
    private let loader: WalletScopedLoader<[InternalNotification]?>

    init(
        tonkeeperAPI: TonkeeperAPI,
        notificationsStore: InternalNotificationsStore,
        walletsStore: WalletsStore
    ) {
        loader = WalletScopedLoader(
            walletsStore: walletsStore,
            fetch: { walletId in
                do {
                    return try await tonkeeperAPI.loadNotifications(walletId: walletId)
                } catch {
                    Log.w("Failed to load internal notifications for wallet \(walletId ?? "none"): \(error)")
                    return nil
                }
            },
            apply: { _, notifications in
                guard let notifications else { return }
                var seen = Set<InternalNotification>()
                let models = notifications
                    .filter { seen.insert($0).inserted }
                    .map { NotificationModel(internalNotification: $0) }
                await notificationsStore.addNotifications(models)
            }
        )
    }

    func loadNotifications(scope: WalletScope, force: Bool) async {
        await loader.reload(scope: scope, force: force)
    }
}
