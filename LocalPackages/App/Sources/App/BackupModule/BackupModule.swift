import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct BackupModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createBackupCoordinator(router: NavigationControllerRouter,
                               wallet: Wallet) -> BackupCoordinator {
    return BackupCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      coreAssembly: dependencies.coreAssembly,
      router: router
    )
  }
}

extension BackupModule {
  struct Dependencies {
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    let coreAssembly: TKCore.CoreAssembly
    
    init(keeperCoreMainAssembly: KeeperCore.MainAssembly,
         coreAssembly: TKCore.CoreAssembly) {
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
      self.coreAssembly = coreAssembly
    }
  }
}
