import Foundation
import KeeperCoreComponents

struct StoriesRepository {
    struct StoryStatus: Codable {
        var isWatched: Bool
        var watchedPageIndex: Int?
    }

    let fileSystemVault: FileSystemVault<[String: StoryStatus], String>

    func getWatchedStories() -> [String] {
        let statuses = getStoryStatuses()
        return statuses.compactMap { id, status in status.isWatched ? id : nil }
    }

    func getStoryStatuses() -> [String: StoryStatus] {
        return (try? fileSystemVault.loadItem(key: .storyStatuses)) ?? [:]
    }

    func getStoryStatus(by id: String) -> StoryStatus? {
        return getStoryStatuses()[id]
    }

    func setStoryStatus(id: String, isWatched: Bool, watchedPageIndex: Int?) {
        var statuses = getStoryStatuses()
        statuses[id] = StoryStatus(isWatched: isWatched, watchedPageIndex: watchedPageIndex)
        try? fileSystemVault.saveItem(statuses, key: .storyStatuses)
    }
}

private extension String {
    static let storyStatuses = "storyStatuses"
}
