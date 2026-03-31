import Foundation

public final class StoriesStore: Store<StoriesStore.Event, StoriesStore.State> {
    public struct State {
        public let watched: [String]
        public let stories: [Story]
    }

    public enum Event {
        case didUpdateState(state: State)
    }

    private let repository: StoriesRepository

    init(repository: StoriesRepository) {
        self.repository = repository
        super.init(state: .init(watched: repository.getWatchedStories(), stories: []))
    }

    override public func createInitialState() -> State {
        .init(watched: self.repository.getWatchedStories(), stories: [])
    }

    public func setStories(_ stories: [Story]) async {
        await withCheckedContinuation { continuation in
            setStories(stories) {
                continuation.resume()
            }
        }
    }

    public func setStories(_ stories: [Story], completion: (() -> Void)? = nil) {
        updateState { state in
            StateUpdate(newState: .init(watched: state.watched, stories: stories))
        } completion: { [weak self] state in
            self?.sendEvent(.didUpdateState(state: state))
            completion?()
        }
    }

    public func setStoryWatchedPageIndex(_ storyId: String, pageIndex: Int) {
        let currentStatus = repository.getStoryStatus(by: storyId)
        let finalIndex = (currentStatus?.watchedPageIndex).map { max($0, pageIndex) } ?? pageIndex
        repository.setStoryStatus(
            id: storyId,
            isWatched: currentStatus?.isWatched ?? false,
            watchedPageIndex: finalIndex
        )
    }

    public func setStoryWatched(_ storyId: String) {
        let currentStatus = repository.getStoryStatus(by: storyId)
        repository.setStoryStatus(
            id: storyId,
            isWatched: true,
            watchedPageIndex: currentStatus?.watchedPageIndex
        )
        updateState { state in
            StateUpdate(newState: .init(watched: self.repository.getWatchedStories(), stories: state.stories))
        } completion: { [weak self] state in
            self?.sendEvent(.didUpdateState(state: state))
        }
    }

    public func nextPageIndex(for storyId: String, totalPages: Int) -> Int {
        let watchedIndex = repository.getStoryStatus(by: storyId)?.watchedPageIndex ?? -1
        let nextIndex = watchedIndex + 1
        guard totalPages > 0 else { return 0 }
        if nextIndex >= totalPages {
            return 0
        }
        return max(0, min(nextIndex, totalPages - 1))
    }
}
