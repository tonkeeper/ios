import FirebaseCore
import Foundation

/// The `app_id` the multichain backend stores on a device registration is the Firebase project
/// number the pusher sends through, so it is read from the bundled Firebase config rather than
/// hardcoded: prod, dev and the X builds sit in different projects. `defaultOptions()` reads
/// `GoogleService-Info.plist` directly, so this also answers before `FirebaseApp.configure()`.
enum FirebasePushAppId {
    static var current: Int64? {
        let senderId = FirebaseApp.app()?.options.gcmSenderID ?? FirebaseOptions.defaultOptions()?.gcmSenderID
        guard let senderId, let appId = Int64(senderId) else {
            return nil
        }
        return appId
    }
}
