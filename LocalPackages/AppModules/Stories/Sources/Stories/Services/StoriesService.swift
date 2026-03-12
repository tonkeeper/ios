import Foundation
import KeeperCore
import TKCore

public protocol StoriesService {
    func loadStory(storyID: String) async throws -> Story
    func isNeedToShow(storyID: String) -> Bool
    func markStoryShown(storyID: String)
    func resetShownStories()
    func prefetchPreviewIcons(storyIDs: [String])
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

    func loadStory(storyID: String) async throws -> Story {
        let story = try await api.loadStory(storyId: storyID)
        return Story(id: storyID, story: story)
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

    func prefetchPreviewIcons(storyIDs: [String]) {
        guard !storyIDs.isEmpty else { return }
        Task.detached { [api] in
            do {
                let stories = try await api.loadStories(storyIds: storyIDs)
                let icons = stories.map { $0.main_screen.icon }
                let previews = stories.map { $0.preview }
                ImagePrefetcherService().prefetch(urls: icons + previews)
            } catch {}
        }
    }
}
