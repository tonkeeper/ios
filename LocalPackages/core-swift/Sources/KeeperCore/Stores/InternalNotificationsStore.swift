import Foundation

public final class InternalNotificationsStore: Store<InternalNotificationsStore.Event, InternalNotificationsStore.State> {
    public typealias State = Set<NotificationModel>
    public enum Event {
        case didUpdateNotifications(notifications: [NotificationModel])
    }

    private let repository: InternalNotificationsRepository

    init(repository: InternalNotificationsRepository) {
        self.repository = repository
        super.init(state: Set())
    }

    override public func createInitialState() -> State {
        Set()
    }

    public func addNotifications(_ notifications: [NotificationModel]) async {
        await withCheckedContinuation { continuation in
            addNotifications(notifications) {
                continuation.resume()
            }
        }
    }

    public func addNotification(_ notification: NotificationModel) async {
        await withCheckedContinuation { continuation in
            addNotification(notification) {
                continuation.resume()
            }
        }
    }

    public func removeNotification(_ notification: NotificationModel, persistant: Bool) async {
        await withCheckedContinuation { continuation in
            removeNotification(notification, persistant: persistant) {
                continuation.resume()
            }
        }
    }

    public func removeNotificationById(_ notificationId: String, persistant: Bool) async {
        await withCheckedContinuation { continuation in
            removeNotificationById(notificationId, persistant: persistant) {
                continuation.resume()
            }
        }
    }

    public func addNotifications(_ notifications: [NotificationModel], completion: (() -> Void)? = nil) {
        updateState { state in
            let removedIds = Set(self.repository.getRemovedNotificationIds())
            let incoming = Set(notifications.filter { !removedIds.contains($0.id) })
            let additions = incoming.subtracting(state)

            guard !additions.isEmpty else { return nil }

            let newState = state.union(additions)
            return StateUpdate(newState: newState)
        } completion: { [weak self] state in
            self?.sendEvent(.didUpdateNotifications(notifications: Array(state)))
            completion?()
        }
    }

    public func addNotification(_ notification: NotificationModel, completion: (() -> Void)?) {
        addNotifications([notification], completion: completion)
    }

    public func removeNotificationById(_ notificationId: String, persistant: Bool, completion: (() -> Void)? = nil) {
        updateState { state in
            let updatedArray = state.filter { $0.id != notificationId }
            let updated = Set(updatedArray)

            guard updated.count != state.count else { return nil }

            return StateUpdate(newState: updated)
        } completion: { [weak self] state in
            self?.sendEvent(.didUpdateNotifications(notifications: Array(state)))
            if persistant == true {
                self?.repository.appendRemovedNotificationId(notificationId)
            }
            completion?()
        }
    }

    public func removeNotification(_ notification: NotificationModel, persistant: Bool, completion: (() -> Void)?) {
        updateState { state in
            let updatedArray = state.filter { $0.id != notification.id }
            let updated = Set(updatedArray)
            return StateUpdate(newState: updated)
        } completion: { [weak self] state in
            self?.sendEvent(.didUpdateNotifications(notifications: Array(state)))
            if persistant == true {
                self?.repository.appendRemovedNotificationId(notification.id)
            }
        }
    }
}
