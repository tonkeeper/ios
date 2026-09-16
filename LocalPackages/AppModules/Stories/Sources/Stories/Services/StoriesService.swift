import Foundation
import KeeperCore
import TKCore

public protocol StoriesService {
    func loadStory(storyID: String, walletId: String?) async throws -> Story
    func loadStories(storyIDs: [String], walletId: String?) async throws -> [Story]
    func isNeedToShow(storyID: String) -> Bool
    func markStoryShown(storyID: String)
    func resetShownStories()
}

final class StoriesServiceImplementation: StoriesService {
    private let api: TonkeeperAPI
    private let shownStoriesRepository: ShownStoriesRepository

    init(
        api: TonkeeperAPI,
        shownStoriesRepository: ShownStoriesRepository
    ) {
        self.api = api
        self.shownStoriesRepository = shownStoriesRepository
    }

    func loadStory(storyID: String, walletId: String?) async throws -> Story {
        let story = try await api.loadStory(storyId: storyID, walletId: walletId)
        return Story(id: storyID, story: story)
    }

    func loadStories(storyIDs: [String], walletId: String?) async throws -> [Story] {
        try await api.loadStories(storyIds: storyIDs, walletId: walletId)
            .map { Story(id: $0.story_id, story: $0) }
    }

    func isNeedToShow(storyID: String) -> Bool {
        do {
            return try !shownStoriesRepository.getShownStories().contains(storyID)
        } catch {
            return true
        }
    }

    func markStoryShown(storyID: String) {
        try? shownStoriesRepository.saveShownStories([storyID])
    }

    func resetShownStories() {
        try? shownStoriesRepository.reset()
    }
}
