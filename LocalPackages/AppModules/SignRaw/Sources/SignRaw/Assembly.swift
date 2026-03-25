import Foundation
import KeeperCore
import TKCore

// @MainActor
// public struct Assembly {
//
//  private let keeperCoreAssembly: KeeperCore.MainAssembly
//  private let coreAssembly: TKCore.CoreAssembly
//
//  public init(keeperCoreAssembly: KeeperCore.MainAssembly,
//              coreAssembly: TKCore.CoreAssembly) {
//    self.keeperCoreAssembly = keeperCoreAssembly
//    self.coreAssembly = coreAssembly
//  }
//
//  public func storiesController() -> StoriesController {
//    StoriesController(
//      storiesService: storiesService(),
//      configuration: keeperCoreAssembly.configurationAssembly.configuration
//    )
//  }
//
//  public func storiesPresenter() -> StoriesPresenter {
//    StoriesPresenter(storiesService: storiesService(),
//                     analyticsProvider: coreAssembly.analyticsProvider)
//  }
//
//  public func storiesService() -> StoriesService {
//    StoriesServiceImplementation(
//      api: keeperCoreAssembly.tonkeeperAPIAssembly.api,
//      shownStoriesRepository: ShownStoriesRepositoryImplementation(
//        fileSystemVault: keeperCoreAssembly.coreAssembly.fileSystemVault()
//      )
//    )
//  }
// }
