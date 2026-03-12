import CoreComponents
import Foundation

public struct InternalNotificationsRepository {
    let fileSystemVault: FileSystemVault<[String], String>

    public func getRemovedNotificationIds() -> [String] {
        let ids = try? fileSystemVault.loadItem(key: .removedNotificationIds)
        return ids ?? []
    }

    public func appendRemovedNotificationId(_ id: String) {
        var ids = getRemovedNotificationIds()
        guard !ids.contains(id) else { return }
        ids.append(id)
        try? fileSystemVault.saveItem(ids, key: .removedNotificationIds)
    }
}

private extension String {
    static let removedNotificationIds = "removedNotificationIds"
}
