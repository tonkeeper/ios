import Foundation

public extension Notification.Name {
    static let foregroundPushReceived = Notification.Name("foregroundPushReceived")
}

public enum PushNotificationTapQueue {
    private static let syncQueue = DispatchQueue(label: "PushNotificationTapQueue")
    private static var pending: [[AnyHashable: Any]?] = []
    private static var onTap: (([AnyHashable: Any]?) -> Void)?
    @MainActor public internal(set) static var isShowingDestination: (@MainActor ([AnyHashable: Any]) -> Bool)?

    public static func enqueue(userInfo: [AnyHashable: Any]?) {
        syncQueue.sync {
            if let handler = onTap {
                DispatchQueue.main.async {
                    handler(userInfo)
                }
            } else {
                pending.append(userInfo)
            }
        }
    }

    static func setHandler(_ handler: @escaping ([AnyHashable: Any]?) -> Void) {
        let queued = syncQueue.sync {
            onTap = handler
            let snapshot = pending
            pending = []
            return snapshot
        }
        DispatchQueue.main.async {
            for userInfo in queued {
                handler(userInfo)
            }
        }
    }

    static func clearHandler() {
        syncQueue.sync {
            onTap = nil
        }
    }
}
