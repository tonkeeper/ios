import CoreComponents
import Foundation

public struct StoriesRepository {
    public struct StoryStatus: Codable {
        public var isWatched: Bool
        public var watchedPageIndex: Int?
    }

    let fileSystemVault: FileSystemVault<[String: StoryStatus], String>

    public func getWatchedStories() -> [String] {
        let statuses = getStoryStatuses()
        return statuses.compactMap { id, status in status.isWatched ? id : nil }
    }

    public func appendWatchedStories(_ id: String) {
        var statuses = getStoryStatuses()
        let existing = statuses[id]
        statuses[id] = StoryStatus(isWatched: true, watchedPageIndex: existing?.watchedPageIndex)
        try? fileSystemVault.saveItem(statuses, key: .storyStatuses)
    }

    public func getStoryStatuses() -> [String: StoryStatus] {
        return (try? fileSystemVault.loadItem(key: .storyStatuses)) ?? [:]
    }

    public func getStoryStatus(by id: String) -> StoryStatus? {
        return getStoryStatuses()[id]
    }

    public func setStoryStatus(id: String, isWatched: Bool, watchedPageIndex: Int?) {
        var statuses = getStoryStatuses()
        statuses[id] = StoryStatus(isWatched: isWatched, watchedPageIndex: watchedPageIndex)
        try? fileSystemVault.saveItem(statuses, key: .storyStatuses)
    }
}

private extension String {
    static let storyStatuses = "storyStatuses"
}
