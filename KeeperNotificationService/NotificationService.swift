import FirebaseMessaging
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Messaging.serviceExtension()
            .exportDeliveryMetricsToBigQuery(withMessageInfo: request.content.userInfo)
        contentHandler(request.content)
    }
}
