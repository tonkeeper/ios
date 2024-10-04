import Foundation

actor InternalNotificationsLoader {
  private var taskInProgress: Task<Void, Never>?
  
  private let tonkeeperAPI: TonkeeperAPI
  private let notificationsStore: InternalNotificationsStore
  
  init(tonkeeperAPI: TonkeeperAPI,
       notificationsStore: InternalNotificationsStore) {
    self.tonkeeperAPI = tonkeeperAPI
    self.notificationsStore = notificationsStore
  }
  
  nonisolated
  func loadNotifications() {
    Task {
      await loadNotifications()
    }
  }
  
  private func loadNotifications() async {
    if let taskInProgress {
      taskInProgress.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      guard let notifications = try? await tonkeeperAPI.loadNotifications() else { return }
      guard !Task.isCancelled else { return }
      var set = Set<InternalNotification>()
      let notificationModels = notifications.filter { set.insert($0).inserted }.map { NotificationModel(internalNotification: $0) }
      await notificationsStore.addNotifications(notificationModels)
    }
    self.taskInProgress = task
  }
}
