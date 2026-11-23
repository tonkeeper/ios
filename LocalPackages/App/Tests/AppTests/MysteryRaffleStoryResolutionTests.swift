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

    func test_bannerRouteFollowsTheCardButton() throws {
        let story = try XCTUnwrap(raffle(storyIds: ["intro"]).stories.first)

        XCTAssertEqual(bannerRoute(.deeplink, "tonkeeper://stories/intro"), .story(story))
        XCTAssertNil(bannerRoute(.deeplink, "tonkeeper://raffle/mystery"))
        XCTAssertEqual(bannerRoute(.deeplink, "tonkeeper://raffle/other"), .deeplink("tonkeeper://raffle/other"))
        XCTAssertEqual(bannerRoute(.link, "https://t.me/tonkeeper"), try .link(XCTUnwrap(URL(string: "https://t.me/tonkeeper"))))
        XCTAssertNil(MysteryRaffleCoordinator.bannerRoute(for: raffle(storyIds: ["intro"]), deeplinkParser: deeplinkParser))
    }

    private let deeplinkParser = DeeplinkParser(walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation())

    private func bannerRoute(_ action: MultichainRaffleCTA.Action, _ payload: String) -> MysteryRaffleCoordinator.BannerRoute? {
        MysteryRaffleCoordinator.bannerRoute(
            for: raffle(storyIds: ["intro"], button: MultichainRaffleCTA(title: "", action: action, payload: payload)),
            deeplinkParser: deeplinkParser
        )
    }

    private func raffle(storyIds: [String], button: MultichainRaffleCTA? = nil) -> MultichainRaffle {
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
            banner: button.map { MultichainRaffleBanner(title: "", description: nil, imageURL: "", button: $0) },
            stories: storyIds.map { id in
                MultichainRaffleStory(
                    id: id,
                    pages: [MultichainRaffleStoryPage(title: "", description: "", image: "")]
                )
            }
        )
    }
}
