import Foundation

public final class NotificationsStore: Store<[NotificationModel]> {
  init() {
    super.init(state: [])
  }
  
  public func addNotification(_ notificationModel: NotificationModel) {
    Task {
      await updateState { notifications in
        guard !notifications.contains(where: { $0.id != notificationModel.id }) else {
          return nil
        }
        let updatedNotifications = notifications + CollectionOfOne(notificationModel)
        return StateUpdate(newState: updatedNotifications)
      }
    }
  }
  
  public func addNotifications(_ notifications: [NotificationModel]) {
    Task {
      await updateState { state in
        let newNotifications = notifications.filter { notification in
          !state.contains(where: { $0.id == notification.id })
        }
        guard !newNotifications.isEmpty else { return nil }
        let updatedNotifications = state + newNotifications
        return StateUpdate(newState: updatedNotifications)
      }
    }
  }
  
  public func removeNotification(_ notification: NotificationModel) {
    Task {
      await updateState { state in
        let updatedNotification = state.filter { $0.id != notification.id }
        return StateUpdate(newState: updatedNotification)
      }
    }
  }
}
