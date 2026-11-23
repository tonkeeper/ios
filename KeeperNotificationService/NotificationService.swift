import FirebaseMessaging
import KeeperCore
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Messaging.serviceExtension()
            .exportDeliveryMetricsToBigQuery(withMessageInfo: request.content.userInfo)
        guard let body = walletNamedBody(userInfo: request.content.userInfo),
              let content = request.content.mutableCopy() as? UNMutableNotificationContent
        else {
            contentHandler(request.content)
            return
        }
        content.body = body
        contentHandler(content)
    }

    private func walletNamedBody(userInfo: [AnyHashable: Any]) -> String? {
        guard let template = PushBodyTemplate(userInfo: userInfo),
              let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
              let sharedCacheURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        else {
            return nil
        }
        return template.body(sharedCacheURL: sharedCacheURL)
    }
}
