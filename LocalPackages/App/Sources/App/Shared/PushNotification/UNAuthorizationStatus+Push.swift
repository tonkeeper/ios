import UserNotifications

extension UNAuthorizationStatus {
    /// `provisional` and `ephemeral` deliver as well — quietly, and for an App Clip's lifetime —
    /// so a permission check has to accept them wherever `authorized` is accepted.
    var isPushAuthorized: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        case .denied, .notDetermined: false
        @unknown default: false
        }
    }
}
