import Foundation

public final class InternalNotificationsStore: StoreV3<InternalNotificationsStore.Event, InternalNotificationsStore.State> {
  public typealias State = [NotificationModel]
  public enum Event {
    case didUpdateNotifications(notifications: [NotificationModel])
  }

  init() {
    super.init(state: [])
  }
  
  public override var initialState: State {
    []
  }
  
  public func addNotifications(_ notifications: [NotificationModel]) async {
    await setState { state in
      let newNotifications = notifications.filter { notification in
        !state.contains(where: { $0.id == notification.id })
      }
      guard !newNotifications.isEmpty else { return nil }
      let updatedNotifications = state + newNotifications
      return StateUpdate(newState: updatedNotifications)
    } notify: { state in
      self.sendEvent(.didUpdateNotifications(notifications: state))
    }
  }
  
  public func addNotification(_ notification: NotificationModel) async {
    await addNotifications([notification])
  }
  
  public func removeNotification(_ notification: NotificationModel) async {
    await setState { state in
      let updatedNotifications = state.filter { $0.id != notification.id }
      return StateUpdate(newState: updatedNotifications)
    } notify: { state in
      self.sendEvent(.didUpdateNotifications(notifications: state))
    }
  }
}
