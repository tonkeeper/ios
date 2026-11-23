import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class StoriesStoreTests: XCTestCase {
    private var storageDirectory: URL!
    private var store: StoriesStore!

    override func setUp() {
        super.setUp()
        storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = StoriesStore(
            repository: StoriesRepository(
                fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
            )
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storageDirectory)
        super.tearDown()
    }

    func test_resumePageIndexContinuesAfterTheLastWatchedPageAndStopsOnTheLastPage() {
        XCTAssertEqual(store.resumePageIndex(for: "perps", totalPages: 4), 0)

        store.setStoryWatchedPageIndex("perps", pageIndex: 1)
        XCTAssertEqual(store.resumePageIndex(for: "perps", totalPages: 4), 2)

        store.setStoryWatchedPageIndex("perps", pageIndex: 3)
        XCTAssertEqual(store.resumePageIndex(for: "perps", totalPages: 4), 3)
        XCTAssertEqual(store.resumePageIndex(for: "perps", totalPages: 2), 1)
    }

    func test_resumePageIndexFollowsTheLastOpenedPageUntilTheLastPageIsReached() {
        store.setStoryWatchedPageIndex("perps", pageIndex: 2)
        store.setStoryWatchedPageIndex("perps", pageIndex: 0)
        XCTAssertEqual(store.resumePageIndex(for: "perps", totalPages: 4), 1)

        store.setStoryWatchedPageIndex("perps", pageIndex: 3)
        store.setStoryWatched("perps")
        store.setStoryWatchedPageIndex("perps", pageIndex: 1)
        XCTAssertEqual(store.resumePageIndex(for: "perps", totalPages: 4), 3)
    }

    func test_nextPageIndexContinuesAfterTheLastOpenedPageOfAWatchedStory() {
        store.setStoryWatchedPageIndex("perps", pageIndex: 3)
        store.setStoryWatched("perps")
        XCTAssertEqual(store.nextPageIndex(for: "perps", totalPages: 4), 0)

        store.setStoryWatchedPageIndex("perps", pageIndex: 1)
        XCTAssertEqual(store.nextPageIndex(for: "perps", totalPages: 4), 2)
    }

    func test_resetStatusesStartsTheStoryOver() {
        store.setStoryWatchedPageIndex("perps", pageIndex: 1)

        store.resetStatuses()

        XCTAssertEqual(store.resumePageIndex(for: "perps", totalPages: 4), 0)
    }
}
