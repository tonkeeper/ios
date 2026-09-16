@testable import App
import Foundation
import Stories
import UIKit
import XCTest

/// Boot-configuration sequencing: `StoriesPresenter` owns a single window, so the stories are
/// chained through dismissals — and the chain has to report back exactly once however it ends,
/// because the raffle's launch story is held back until it does.
@MainActor
final class BootConfigurationStoriesQueueTests: XCTestCase {
    private var presenter: SpyBootStoryPresenter!
    private var loader: StubBootStoriesLoader!
    private var controller: MainCoordinatorStoriesController!
    private var fromViewController: UIViewController!

    override func setUp() {
        super.setUp()
        presenter = SpyBootStoryPresenter()
        loader = StubBootStoriesLoader()
        controller = MainCoordinatorStoriesController(storiesPresenter: presenter, storiesController: loader)
        fromViewController = UIViewController()
        let fromViewController = fromViewController
        controller.fromViewControllerProvider = { fromViewController }
    }

    override func tearDown() {
        presenter = nil
        loader = nil
        controller = nil
        fromViewController = nil
        super.tearDown()
    }

    func test_completingAStoryPlaysTheNextOneInConfigurationOrder() async {
        var didComplete: Bool?
        start(storyIDs: ["intro", "prizes", "tasks"]) { didComplete = $0 }
        await settle()

        XCTAssertEqual(presenter.presentedStoryIds, ["intro"])

        await dismissCurrent(reason: .completed)
        XCTAssertEqual(presenter.presentedStoryIds, ["intro", "prizes"])

        await dismissCurrent(reason: .completed)
        XCTAssertEqual(presenter.presentedStoryIds, ["intro", "prizes", "tasks"])
        XCTAssertNil(didComplete, "the run is still on screen")

        await dismissCurrent(reason: .completed)
        XCTAssertEqual(didComplete, true)
    }

    func test_runPlaysTheAutoplayStoriesInConfigurationOrder() async {
        loader.configurationStoryIDs = ["promo", "multichain", "raffle", "multichain-raffle"]
        loader.autoShowStoryIDs = ["promo", "multichain-raffle"]
        var didComplete: Bool?

        controller.runBootConfigurationStories(
            walletId: nil,
            didPresentStory: { _ in },
            completion: { didComplete = $0 }
        )
        await settle()

        XCTAssertEqual(presenter.presentedStoryIds, ["promo"])

        await dismissCurrent(reason: .completed)
        XCTAssertEqual(loader.autoplayStoriesCallCount, 1)
        XCTAssertEqual(presenter.presentedStoryIds, ["promo", "multichain-raffle"])

        await dismissCurrent(reason: .completed)
        XCTAssertEqual(didComplete, true)
    }

    func test_closeEndsTheRunWithoutPlayingTheRest() async {
        var didComplete: Bool?
        start(storyIDs: ["intro", "prizes"]) { didComplete = $0 }
        await settle()

        await dismissCurrent(reason: .closed)

        XCTAssertEqual(presenter.presentedStoryIds, ["intro"])
        XCTAssertEqual(didComplete, false)
    }

    /// A page button routes the user somewhere; the rest of the sequence must not land on top
    /// of wherever they end up, and the caller has to hear that the run ended early.
    func test_pageButtonEndsTheRunWithoutPlayingTheRest() async {
        var didComplete: Bool?
        start(storyIDs: ["intro", "prizes"]) { didComplete = $0 }
        await settle()

        await dismissCurrent(reason: .action)

        XCTAssertEqual(presenter.presentedStoryIds, ["intro"])
        XCTAssertEqual(didComplete, false)
    }

    /// The presenter drops stories it can't show (no scene, remotely disabled) without ever
    /// reporting a dismissal, so those steps have to unwind on their own — and still finish.
    func test_refusedPresentationSkipsTheStoryAndFinishesTheRun() async {
        presenter.canPresent = false
        var didComplete: Bool?
        start(storyIDs: ["intro", "prizes"]) { didComplete = $0 }
        await settle()

        XCTAssertEqual(presenter.presentedStoryIds, [])
        XCTAssertEqual(didComplete, true)
    }

    /// The claim the raffle auto-open reads has to land before `StoriesService` records the
    /// story, so it must be reported at presentation time rather than at dismissal.
    func test_presentedStoriesAreReportedAsSoonAsTheyGoOnScreen() async {
        var reportedStoryIDs = [String]()
        controller.presentBootConfigurationStories(
            stories: stories(["intro", "prizes"]),
            didPresentStory: { reportedStoryIDs.append($0) },
            completion: { _ in }
        )
        await settle()

        XCTAssertEqual(reportedStoryIDs, ["intro"])

        await dismissCurrent(reason: .completed)
        XCTAssertEqual(reportedStoryIDs, ["intro", "prizes"])
    }

    func test_refusedPresentationIsNotReportedAsPresented() async {
        presenter.canPresent = false
        var reportedStoryIDs = [String]()
        controller.presentBootConfigurationStories(
            stories: stories(["intro"]),
            didPresentStory: { reportedStoryIDs.append($0) },
            completion: { _ in }
        )
        await settle()

        XCTAssertEqual(reportedStoryIDs, [])
    }

    func test_emptyConfigurationFinishesWithoutPresentingAnything() {
        var didComplete: Bool?
        start(storyIDs: []) { didComplete = $0 }

        XCTAssertEqual(didComplete, true)
        XCTAssertEqual(presenter.presentedStoryIds, [])
    }

    /// A deeplink or a push tap takes over the launch: the sequence advances on dismissals
    /// rather than on suspension points, so cancellation is what stops it.
    func test_cancellationStopsTheRunAndReportsItAsUnfinished() async {
        var didComplete: Bool?
        start(storyIDs: ["intro", "prizes"]) { didComplete = $0 }
        await settle()

        controller.cancelBootConfigurationStories()
        await settle()

        XCTAssertEqual(presenter.presentedStoryIds, ["intro"])
        XCTAssertEqual(didComplete, false)
        XCTAssertEqual(presenter.dismissCurrentStoryCallCount, 1)
    }

    func test_cancellationWithoutActiveRunDoesNotDismissCurrentStory() {
        controller.cancelBootConfigurationStories()

        XCTAssertEqual(presenter.dismissCurrentStoryCallCount, 0)
    }

    func test_runEndingBeforePresentationDoesNotLeaveCancellationArmed() async {
        controller.fromViewControllerProvider = { nil }
        var didComplete: Bool?
        start(storyIDs: ["intro"]) { didComplete = $0 }
        await settle()

        controller.cancelBootConfigurationStories()

        XCTAssertEqual(didComplete, false)
        XCTAssertEqual(presenter.dismissCurrentStoryCallCount, 0)
    }

    func test_cancellationWhileLoadingConfigurationDoesNotStartTheRun() async {
        loader.configurationStoryIDs = ["intro"]
        loader.autoShowStoryIDs = ["intro"]
        loader.isConfigurationLoadingSuspended = true
        var didComplete: Bool?
        controller.runBootConfigurationStories(
            walletId: nil,
            didPresentStory: { _ in },
            completion: { didComplete = $0 }
        )
        await settle()

        controller.cancelBootConfigurationStories()
        loader.resumeConfigurationLoading()
        await settle()

        XCTAssertEqual(presenter.presentedStoryIds, [])
        XCTAssertEqual(didComplete, false)
    }

    func test_completionRunsExactlyOnce() async {
        var completionCount = 0
        start(storyIDs: ["intro", "prizes"]) { _ in completionCount += 1 }
        await settle()

        await dismissCurrent(reason: .completed)
        await dismissCurrent(reason: .completed)
        await dismissCurrent(reason: .completed)

        XCTAssertEqual(completionCount, 1)
    }

    private func start(storyIDs: [String], completion: @escaping (Bool) -> Void) {
        controller.presentBootConfigurationStories(
            stories: stories(storyIDs),
            didPresentStory: { _ in },
            completion: completion
        )
    }

    private func stories(_ storyIDs: [String]) -> [Stories.Story] {
        storyIDs.map { Stories.Story(id: $0, pages: [], isAutoShow: true) }
    }

    private func dismissCurrent(reason: Stories.StoriesPresenter.DismissReason) async {
        presenter.dismissCurrent(reason: reason)
        await settle()
    }

    /// Every step of the chain runs in a task of its own, and the run starts behind an `await`
    /// that hops off the main actor, so yielding the main actor alone doesn't drain it — the
    /// turns need real time to come back.
    private func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        }
    }
}

/// Stands in for `StoriesPresenter`: records what was opened and hands the dismissal back to
/// the test, since the chain advances on dismissals.
@MainActor
private final class SpyBootStoryPresenter: RaffleStoryPresenting {
    var canPresent = true
    private(set) var presentedStoryIds: [String] = []
    private(set) var dismissCurrentStoryCallCount = 0
    private var onDismiss: ((Stories.StoriesPresenter.DismissReason) -> Void)?

    func presentStory(
        story: Stories.Story,
        fromViewController: UIViewController,
        fromAnalyticsProperty: String,
        deeplinkAction: @escaping (String) -> Void,
        urlAction: @escaping (URL) -> Void,
        onDismiss: ((Stories.StoriesPresenter.DismissReason) -> Void)?
    ) -> Bool {
        guard canPresent else { return false }
        presentedStoryIds.append(story.id)
        self.onDismiss = onDismiss
        return true
    }

    func dismissCurrent(reason: Stories.StoriesPresenter.DismissReason) {
        let onDismiss = onDismiss
        self.onDismiss = nil
        onDismiss?(reason)
    }

    func dismissCurrentStory() {
        dismissCurrentStoryCallCount += 1
        dismissCurrent(reason: .closed)
    }
}

private final class StubBootStoriesLoader: BootConfigurationStoriesLoading {
    var configurationStoryIDs: [String] = []
    var autoShowStoryIDs = Set<String>()
    var isConfigurationLoadingSuspended = false
    private(set) var autoplayStoriesCallCount = 0
    private var configurationContinuation: CheckedContinuation<Void, Never>?

    func autoplayStories(walletId _: String?) async -> [Stories.Story] {
        autoplayStoriesCallCount += 1
        if isConfigurationLoadingSuspended {
            await withCheckedContinuation { continuation in
                configurationContinuation = continuation
            }
        }
        return configurationStoryIDs
            .filter { autoShowStoryIDs.contains($0) }
            .map { Stories.Story(id: $0, pages: [], isAutoShow: true) }
    }

    func loadStory(
        storyId: String,
        ignoreShowed: Bool,
        walletId _: String?
    ) async -> Result<Stories.Story, Stories.StoriesController.Error> {
        .success(
            Stories.Story(
                id: storyId,
                pages: [],
                isAutoShow: autoShowStoryIDs.contains(storyId)
            )
        )
    }

    func resumeConfigurationLoading() {
        configurationContinuation?.resume()
        configurationContinuation = nil
    }
}
