import Foundation

public final class StoriesAssembly {
  
  private let tonkeeperApiAssembly: TonkeeperAPIAssembly
  private let configurationAssembly: ConfigurationAssembly
  private let coreAssembly: CoreAssembly
  
  init(tonkeeperApiAssembly: TonkeeperAPIAssembly,
       configurationAssembly: ConfigurationAssembly,
       coreAssembly: CoreAssembly) {
    self.tonkeeperApiAssembly = tonkeeperApiAssembly
    self.configurationAssembly = configurationAssembly
    self.coreAssembly = coreAssembly
  }
  
  private weak var _storyProvider: StoryProvider?
  public var storyProvider: StoryProvider {
    if let storyProvider = _storyProvider {
      return storyProvider
    } else {
      let storyProvider = StoryProvider(storiesService: storiesService())
      _storyProvider = storyProvider
      return storyProvider
    }
  }
  
  func shownStoriesRepository() -> ShownStoriesRepository {
    ShownStoriesRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
  }
  
  func storiesService() -> StoriesService {
    StoriesServiceImplementation(
      api: tonkeeperApiAssembly.api, shownStoriesRepository: shownStoriesRepository(),
      configuration: configurationAssembly.configuration
    )
  }
}
