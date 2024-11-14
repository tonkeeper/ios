import Foundation

public final class InternalNotificationsStore: Store<InternalNotificationsStore.Event, InternalNotificationsStore.State> {
  public typealias State = [NotificationModel]
  public enum Event {
    case didUpdateNotifications(notifications: [NotificationModel])
  }

  init() {
    super.init(state: [])
  }
  
  public override func createInitialState() -> State {
    []
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
  
  public func removeNotification(_ notification: NotificationModel) async {
    await withCheckedContinuation { continuation in
      removeNotification(notification) {
        continuation.resume()
      }
    }
  }
  
  public func addNotifications(_ notifications: [NotificationModel], completion: (() -> Void)?) {
    updateState { state in
      let newNotifications = notifications.filter { notification in
        !state.contains(where: { $0.id == notification.id })
      }
      guard !newNotifications.isEmpty else { return nil }
      let updatedNotifications = state + newNotifications
      return StateUpdate(newState: updatedNotifications)
    } completion: { [weak self] state in
      self?.sendEvent(.didUpdateNotifications(notifications: state))
    }
  }
  
  public func addNotification(_ notification: NotificationModel, completion: (() -> Void)?) {
    addNotifications([notification], completion: completion)
  }
 
  public func removeNotification(_ notification: NotificationModel, completion: (() -> Void)?) {
    updateState { state in
      let updatedNotifications = state.filter { $0.id != notification.id }
      return StateUpdate(newState: updatedNotifications)
    } completion: { [weak self] state in
      self?.sendEvent(.didUpdateNotifications(notifications: state))
    }
  }
}
