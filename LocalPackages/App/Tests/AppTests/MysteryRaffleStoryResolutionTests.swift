@testable import App
import Foundation
@testable import KeeperCore
import XCTest

/// The contract doesn't spell out how a `.deeplink` CTA payload names one of the raffle's
/// own stories, so the resolver accepts several shapes — and must leave anything else to
/// the generic deeplink dispatch.
final class MysteryRaffleStoryResolutionTests: XCTestCase {
    func test_resolvesBareStoryId() {
        let raffle = raffle(storyIds: ["intro", "prizes"])

        let story = MysteryRaffleStoriesRouter.story(forPayload: "prizes", in: raffle)

        XCTAssertEqual(story?.id, "prizes")
    }

    func test_resolvesLastPathComponentOfDeeplink() {
        let raffle = raffle(storyIds: ["intro"])

        let story = MysteryRaffleStoriesRouter.story(forPayload: "tonkeeper://stories/intro", in: raffle)

        XCTAssertEqual(story?.id, "intro")
    }

    func test_resolvesIdQueryItem() {
        let raffle = raffle(storyIds: ["intro"])

        let story = MysteryRaffleStoriesRouter.story(forPayload: "tonkeeper://stories?id=intro", in: raffle)

        XCTAssertEqual(story?.id, "intro")
    }

    /// A swap/migration deeplink must fall through, otherwise the generic dispatch never runs.
    func test_unrelatedDeeplinkResolvesToNil() {
        let raffle = raffle(storyIds: ["intro"])

        XCTAssertNil(MysteryRaffleStoriesRouter.story(forPayload: "tonkeeper://swap", in: raffle))
        XCTAssertNil(MysteryRaffleStoriesRouter.story(forPayload: "tonkeeper://stories/other", in: raffle))
    }

    func test_raffleWithoutStoriesResolvesToNil() {
        XCTAssertNil(MysteryRaffleStoriesRouter.story(forPayload: "intro", in: raffle(storyIds: [])))
    }

    private func raffle(storyIds: [String]) -> MultichainRaffle {
        MultichainRaffle(
            id: "mystery",
            status: .joined,
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
                    pages: [MultichainRaffleStoryPage(title: "", description: "", image: "")]
                )
            }
        )
    }
}
