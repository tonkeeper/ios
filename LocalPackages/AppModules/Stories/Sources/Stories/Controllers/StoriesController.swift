import Foundation
import KeeperCore
import TKUIKit

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
            !configuration.isPromoHidden(id: storyId)
                && claimedStoryIds.insert(storyId).inserted
                && storiesService.isNeedToShow(storyID: storyId)
        }
        guard !candidates.isEmpty,
              !candidatesWithoutAutoplay.contains(candidates),
              let loadedStories = try? await storiesService.loadStories(storyIDs: candidates, walletId: walletId),
              !loadedStories.isEmpty
        else {
            return []
        }
        prefetchImages(of: loadedStories)

        let storiesById = Dictionary(loadedStories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let autoplayStories = candidates.compactMap { storiesById[$0] }.filter(\.isAutoShow)
        if autoplayStories.isEmpty {
            candidatesWithoutAutoplay.insert(candidates)
        }
        return autoplayStories
    }

    public func prefetchStory(storyId: String, walletId: String?) async {
        guard let story = try? await storiesService.loadStory(storyID: storyId, walletId: walletId) else { return }
        prefetchImages(of: [story])
    }

    public func loadStory(storyId: String, ignoreShowed: Bool, walletId: String?) async -> Result<Story, Error> {
        guard ignoreShowed || storiesService.isNeedToShow(storyID: storyId) else {
            return .failure(.allStoriesShown)
        }
        _ = await configuration.loadConfigurations()
        guard !configuration.isPromoHidden(id: storyId) else {
            return .failure(.failedLoadStory(storyId: storyId))
        }
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

    private nonisolated func prefetchImages(of stories: [Story]) {
        ImagePrefetcherService().prefetch(urls: stories.flatMap { $0.pages.compactMap(\.image) })
    }
}
