import Foundation

actor StonfiPairsLoader {
  private var taskInProgress: Task<(), Swift.Error>?
  
  private let stonfiPairsStore: StonfiPairsStore
  private let stonfiPairsService: StonfiPairsService
  
  init(stonfiPairsStore: StonfiPairsStore,
       stonfiPairsService: StonfiPairsService) {
    self.stonfiPairsStore = stonfiPairsStore
    self.stonfiPairsService = stonfiPairsService
  }
  
  func loadPairs() async {
    if let taskInProgress = taskInProgress {
      taskInProgress.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      let pairs = try await stonfiPairsService.loadPairs()
      
      guard !Task.isCancelled else { return }
      await stonfiPairsStore.setPairs(pairs)
    }
    
    taskInProgress = task
  }
}
