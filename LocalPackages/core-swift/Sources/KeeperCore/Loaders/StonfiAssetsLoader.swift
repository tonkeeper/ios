import Foundation

actor StonfiAssetsLoader {
  private var taskInProgress: Task<(), Swift.Error>?
  
  private let stonfiAssetsStore: StonfiAssetsStore
  private let stonfiAssetsService: StonfiAssetsService
  
  init(stonfiAssetsStore: StonfiAssetsStore,
       stonfiAssetsService: StonfiAssetsService) {
    self.stonfiAssetsStore = stonfiAssetsStore
    self.stonfiAssetsService = stonfiAssetsService
  }
  
  func loadAssets(excludeCommunityAssets: Bool = true) async {
    if let taskInProgress = taskInProgress {
      taskInProgress.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      let assets = try await stonfiAssetsService.loadAssets()
      
      guard !Task.isCancelled else { return }
      await stonfiAssetsStore.setAssets(assets)
    }
    
    taskInProgress = task
  }
}
