import Foundation
import KeeperCore

@MainActor
public struct Assembly {
  
  private let keeperCoreAssembly: KeeperCore.MainAssembly
  
  public init(keeperCoreAssembly: KeeperCore.MainAssembly) {
    self.keeperCoreAssembly = keeperCoreAssembly
  }
  
  public func storiesController() -> StoriesController {
    StoriesController(
      storiesService: storiesService(),
      configuration: keeperCoreAssembly.configurationAssembly.configuration
    )
  }
  
  public func storiesPresenter() -> StoriesPresenter {
    StoriesPresenter(storiesService: storiesService())
  }
  
  private func storiesService() -> StoriesService {
    StoriesServiceImplementation(
      api: keeperCoreAssembly.tonkeeperAPIAssembly.api,
      shownStoriesRepository: ShownStoriesRepositoryImplementation(
        fileSystemVault: keeperCoreAssembly.coreAssembly.fileSystemVault()
      )
    )
  }
}
