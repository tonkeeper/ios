@testable import App
import Foundation
@testable import KeeperCore
import Stories
import UIKit
import XCTest

/// Auto-open sequencing: a raffle can carry several stories at once, and the shared
/// presenter owns a single window, so they have to be chained through dismissals — and the
/// chain must always end, otherwise auto-open stays blocked for the rest of the session.
@MainActor
final class MysteryRaffleStoryQueueTests: XCTestCase {
    private var presenter: SpyStoryPresenter!
    private var service: StubStoriesService!
    private var router: MysteryRaffleStoriesRouter!
    private var viewController: UIViewController!

    override func setUp() {
        super.setUp()
        presenter = SpyStoryPresenter()
        service = StubStoriesService()
        router = MysteryRaffleStoriesRouter(storiesPresenter: presenter, storiesService: service)
        viewController = UIViewController()
    }

    func test_playsEveryUnshownStoryInBackendOrder() async {
        XCTAssertTrue(startAutoOpen(storyIds: ["intro", "prizes", "tasks"]))

        await dismissCurrent(reason: .completed)
        await dismissCurrent(reason: .completed)

        XCTAssertEqual(presenter.presentedStoryIds, ["intro", "prizes", "tasks"])
    }

    func test_closeEndsTheRunWithoutPlayingTheRest() async {
        XCTAssertTrue(startAutoOpen(storyIds: ["intro", "prizes"]))

        await dismissCurrent(reason: .closed)

        XCTAssertEqual(presenter.presentedStoryIds, ["intro"])
    }

    func test_alreadyShownStoriesAreSkipped() {
        service.shownStoryIds = ["intro"]

        startAutoOpen(storyIds: ["intro", "prizes"])

        XCTAssertEqual(presenter.presentedStoryIds, ["prizes"])
    }

    /// The boot stories claim what they put on screen a turn before `StoriesService` records
    /// it, and that record is written with `try?` — so the claim has to stand on its own when
    /// the persistence write is the thing that failed.
    func test_storyClaimedByBootConfigurationIsSkippedEvenWhenNotRecordedAsShown() {
        router.excludeAutoOpenStoryIDs(["intro"])
        XCTAssertTrue(service.isNeedToShow(storyID: "intro"))

        startAutoOpen(storyIds: ["intro", "prizes"])

        XCTAssertEqual(presenter.presentedStoryIds, ["prizes"])
    }

    /// A page button routes the user somewhere; the rest of the queue must not land on top
    /// of wherever they end up — and must stay available for the next auto-open.
    func test_pageButtonEndsTheRunAndLeavesTheRestUnclaimed() async {
        let raffle = raffle(storyIds: ["intro", "prizes"])
        router.presentAutoOpenStories(in: raffle, from: viewController, source: "test", openDeeplink: nil)

        await dismissCurrent(reason: .action)

        XCTAssertEqual(presenter.presentedStoryIds, ["intro"])

        router.presentAutoOpenStories(in: raffle, from: viewController, source: "test", openDeeplink: nil)

        XCTAssertEqual(presenter.presentedStoryIds, ["intro", "prizes"])
    }

    /// Launch and the raffle sheet resolve the same store emission; the second one must not
    /// replace the window the first one is already showing a story in.
    func test_secondRunIsIgnoredWhileOneIsInFlight() {
        let raffle = raffle(storyIds: ["intro", "prizes"])
        router.presentAutoOpenStories(in: raffle, from: viewController, source: "launch", openDeeplink: nil)

        XCTAssertFalse(router.presentAutoOpenStories(in: raffle, from: viewController, source: "sheet", openDeeplink: nil))
        XCTAssertEqual(presenter.presentedStoryIds, ["intro"])
    }

    /// The presenter drops stories it can't show (no scene, remotely disabled) without ever
    /// reporting a dismissal — the run has to unwind on its own.
    func test_refusedPresentationUnwindsTheRun() {
        presenter.canPresent = false

        XCTAssertFalse(startAutoOpen(storyIds: ["intro"]))

        presenter.canPresent = true

        XCTAssertTrue(startAutoOpen(storyIds: ["intro"]))
    }

    func test_raffleWithoutStoriesStartsNothing() {
        XCTAssertFalse(startAutoOpen(storyIds: []))
    }

    func test_emptyStoryDoesNotBlockFollowingValidStory() {
        XCTAssertTrue(startAutoOpen(storyIds: ["empty", "valid"], emptyStoryIds: ["empty"]))

        XCTAssertEqual(presenter.presentedStoryIds, ["valid"])
    }

    /// The queue starts the next story a turn after the dismissal (it lands inside the
    /// dismissal transition's teardown), so let that turn run before asserting.
    private func dismissCurrent(reason: Stories.StoriesPresenter.DismissReason) async {
        presenter.dismissCurrent(reason: reason)
        await Task.yield()
    }

    @discardableResult
    private func startAutoOpen(storyIds: [String], emptyStoryIds: Set<String> = []) -> Bool {
        router.presentAutoOpenStories(
            in: raffle(storyIds: storyIds, emptyStoryIds: emptyStoryIds),
            from: viewController,
            source: "test",
            openDeeplink: nil
        )
    }

    private func raffle(storyIds: [String], emptyStoryIds: Set<String> = []) -> MultichainRaffle {
        MultichainRaffle(
            id: "mystery",
            status: .notJoined,
            hero: MultichainRaffleHero(image: "", badgeIconId: nil),
            title: "",
            subtitle: "",
            startsAt: Date(),
            endsAt: Date(),
            prizesRevealAt: nil,
            compactBanner: MultichainRaffleCompactBanner(defaultTitle: "", activeTitle: "", iconId: "ticket"),
            prizesHeader: "",
            statusBadge: nil,
            prizes: [],
            tasks: [],
            milestones: [],
            cta: MultichainRaffleCTA(title: "", action: .deeplink, payload: ""),
            progress: nil,
            stories: storyIds.map { id in
                MultichainRaffleStory(
                    id: id,
                    pages: emptyStoryIds.contains(id)
                        ? []
                        : [MultichainRaffleStoryPage(title: "", description: "", image: "")]
                )
            }
        )
    }
}

/// Stands in for `StoriesPresenter`: records what was opened and hands the dismissal back
/// to the test, since the queue advances on dismissals.
@MainActor
private final class SpyStoryPresenter: RaffleStoryPresenting {
    var canPresent = true
    private(set) var presentedStoryIds: [String] = []
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
        dismissCurrent(reason: .closed)
    }
}

private final class StubStoriesService: Stories.StoriesService {
    var shownStoryIds: Set<String> = []

    func loadStory(storyID: String, walletId _: String?) async throws -> Stories.Story {
        Stories.Story(id: storyID, pages: [])
    }

    func loadStories(storyIDs: [String], walletId _: String?) async throws -> [Stories.Story] {
        storyIDs.map { Stories.Story(id: $0, pages: []) }
    }

    func isNeedToShow(storyID: String) -> Bool {
        !shownStoryIds.contains(storyID)
    }

    func markStoryShown(storyID: String) {
        shownStoryIds.insert(storyID)
    }

    func resetShownStories() {
        shownStoryIds.removeAll()
    }
}
