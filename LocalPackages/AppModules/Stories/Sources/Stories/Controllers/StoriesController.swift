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

    private var candidatesWithoutAutoplay: Set<[String]> = []

    init(
        storiesService: StoriesService,
        configuration: Configuration
    ) {
        self.storiesService = storiesService
        self.configuration = configuration
    }

    public func autoplayStories(walletId: String?) async -> [Story] {
        let storyIds = await configuration.stories
        var claimedStoryIds = Set<String>()
        let candidates = storyIds.filter { storyId in
            claimedStoryIds.insert(storyId).inserted && storiesService.isNeedToShow(storyID: storyId)
        }
        guard !candidates.isEmpty,
              !candidatesWithoutAutoplay.contains(candidates),
              let loadedStories = try? await storiesService.loadStories(storyIDs: candidates, walletId: walletId),
              !loadedStories.isEmpty
        else {
            return []
        }

        let storiesById = Dictionary(loadedStories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let autoplayStories = candidates.compactMap { storiesById[$0] }.filter(\.isAutoShow)
        if autoplayStories.isEmpty {
            candidatesWithoutAutoplay.insert(candidates)
        }
        return autoplayStories
    }

    public func loadStory(storyId: String, ignoreShowed: Bool, walletId: String?) async -> Result<Story, Error> {
        do {
            let story = try await storiesService.loadStory(storyID: storyId, walletId: walletId)
            guard ignoreShowed || storiesService.isNeedToShow(storyID: storyId) else {
                return .failure(.allStoriesShown)
            }
            return .success(story)
        } catch {
            return .failure(.failedLoadStory(storyId: storyId))
        }
    }
}
