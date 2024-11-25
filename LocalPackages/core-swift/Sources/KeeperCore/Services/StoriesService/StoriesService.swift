import Foundation
import TonAPI

public protocol StoriesService {
  func loadStoryToShow() async throws -> Story?
}

final class StoriesServiceImplementation: StoriesService {
  private let api: TonkeeperAPI
  private let shownStoriesRepository: ShownStoriesRepository
  private let configuration: Configuration
  
  init(api: TonkeeperAPI,
       shownStoriesRepository: ShownStoriesRepository,
       configuration: Configuration) {
    self.api = api
    self.shownStoriesRepository = shownStoriesRepository
    self.configuration = configuration
  }
  
  func loadStoryToShow() async throws -> Story? {
    do {
      let storiesToShow = await configuration.stories
      var shownStories = try getShownStories()
      let newStories = storiesToShow.filter { !shownStories.contains($0) }
      guard let storyToShow = newStories.first else {
        return nil
      }
      let story = try await api.loadStory(storyId: storyToShow)
      shownStories.append(storyToShow)
      try saveShownStories(shownStories)
      return story
    } catch {
      throw error
    }
  }
  
  func getShownStories() throws -> [String] {
    try shownStoriesRepository.getShownStories()
  }
  
  func saveShownStories(_ shownStories: [String]) throws {
    try shownStoriesRepository.saveShownStories(shownStories)
  }
}
