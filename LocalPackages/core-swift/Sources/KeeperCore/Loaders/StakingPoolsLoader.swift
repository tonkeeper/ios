import Foundation
import TonSwift

actor StakingPoolsLoader {
  private var taskInProgress: Task<(), Swift.Error>?
  private let service: StakingPoolsService
  
  init(service: StakingPoolsService) {
    self.service = service
  }
  
  func loadPools(wallet: Wallet, includeUnverified: Bool) async {
    if let taskInProgress {
      taskInProgress.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      _ = try await service.loadAvailablePools(
        address: wallet.address,
        isTestnet: wallet.isTestnet,
        includeUnverified: includeUnverified
      )
    }
    
    taskInProgress = task
  }
}

