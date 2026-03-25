import FirebaseCore
import FirebaseMessaging
import Foundation

public final class PushNotificationTokenProvider: NSObject, MessagingDelegate {
    public var didUpdateToken: ((String?) -> Void)?

    public func setup() {
        Messaging.messaging().delegate = self
    }

    public func getToken() async -> String? {
        try? await Messaging.messaging().token()
    }

    public func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        didUpdateToken?(fcmToken)
    }
}
