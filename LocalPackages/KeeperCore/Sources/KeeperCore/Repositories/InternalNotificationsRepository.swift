import Foundation
import KeeperCoreComponents

struct InternalNotificationsRepository {
    let fileSystemVault: FileSystemVault<[String], String>

    func getRemovedNotificationIds() -> [String] {
        let ids = try? fileSystemVault.loadItem(key: .removedNotificationIds)
        return ids ?? []
    }

    func appendRemovedNotificationId(_ id: String) {
        var ids = getRemovedNotificationIds()
        guard !ids.contains(id) else { return }
        ids.append(id)
        try? fileSystemVault.saveItem(ids, key: .removedNotificationIds)
    }
}

private extension String {
    static let removedNotificationIds = "removedNotificationIds"
}
