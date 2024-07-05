import Foundation

actor InternalNotificationsLoader {
  private var taskInProgress: Task<Void, Never>?
  
  private let tonkeeperAPI: TonkeeperAPI
  private let notificationsStore: NotificationsStore
  
  init(tonkeeperAPI: TonkeeperAPI,
       notificationsStore: NotificationsStore) {
    self.tonkeeperAPI = tonkeeperAPI
    self.notificationsStore = notificationsStore
  }
  
  nonisolated
  func loadNotifications(platform: String, version: String, lang: String) {
    Task {
      await loadNotifications(platform: platform, version: version, lang: lang)
    }
  }
  
  private func loadNotifications(platform: String, version: String, lang: String) async {
    if let taskInProgress {
      taskInProgress.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      guard let notifications = try? await tonkeeperAPI.loadNotifications() else { return }
      guard !Task.isCancelled else { return }
      var set = Set<InternalNotification>()
      let notificationModels = notifications.filter { set.insert($0).inserted }.map { NotificationModel(internalNotification: $0) }
      notificationsStore.addNotifications(notificationModels)
    }
    self.taskInProgress = task
  }
}
