import Foundation
import KeeperCore

public actor StoriesController {
  
  public enum Error: Swift.Error {
    case failedLoadStory(storyId: String)
    case noStories
    case allStoriesShown
  }
  
  private let storiesService: StoriesService
  private let configuration: Configuration

  init(storiesService: StoriesService,
       configuration: Configuration) {
    self.storiesService = storiesService
    self.configuration = configuration
  }
  
  public func loadStories() async -> Result<Story, Error> {
    let stories = await configuration.stories
    guard let storyId = stories.first else { return .failure(.noStories) }
    do {
      let story = try await storiesService.loadStory(storyID: storyId)
      guard storiesService.isNeedToShow(storyID: storyId) else {
        return .failure(.allStoriesShown)
      }
      return .success(story)
    } catch {
      return .failure(.failedLoadStory(storyId: storyId))
    }
  }
}
