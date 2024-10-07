import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct StoriesModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func storiesModule(pages: [StoriesController.StoryPage]) -> MVVMModule<StoriesViewController, StoriesModuleOutput, Void> {
    let storiesController = dependencies.keeperCoreMainAssembly.storiesController(pages: pages)
    return StoriesAssembly.module(
      storiesController: storiesController
    )
  }
}

extension StoriesModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}
