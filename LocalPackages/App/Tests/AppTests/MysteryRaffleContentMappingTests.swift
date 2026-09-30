@testable import App
import Foundation
@testable import KeeperCore
import TKLocalize
import XCTest

/// The modal renders whatever the payload carries: sections follow their arrays, the
/// ticket counter follows the earn sections, and the hero's clock follows whichever
/// boundary is still ahead. `status` is read only where the payload can't say it — the
/// results screen and the ended-awaiting-reveal tally; its not_joined / joined (i.e. "no
/// tickets yet" / "has tickets") never picks a layout.
final class MysteryRaffleContentMappingTests: XCTestCase {
    // MARK: - Launch payload (no prizes / milestones yet)

    func test_launchPayloadShowsBenefitCardsAndNoTicketsCard() {
        let content = MysteryRaffleContent(raffle: launchRaffle())

        XCTAssertEqual(content.benefitCards.count, 2)
        XCTAssertFalse(content.showsTicketsCard)
        XCTAssertNil(content.tickets.getMoreTitle)
        XCTAssertTrue(content.earnTasks.isEmpty)
        XCTAssertEqual(content.statusBadge?.icon, .fire)
    }

    /// Earning the launch tickets flips `status` to joined, which must change the badge
    /// glyph and nothing else about the layout.
    func test_launchPayloadWithTicketsKeepsTheSameLayout() {
        let content = MysteryRaffleContent(
            raffle: launchRaffle(status: .joined, ticketsTotal: 10)
        )

        XCTAssertFalse(content.showsTicketsCard)
        XCTAssertEqual(content.benefitCards.count, 2)
        XCTAssertTrue(content.earnTasks.isEmpty)
        XCTAssertEqual(content.statusBadge?.icon, .checkmarkCircle)
    }

    /// The launch hero shows the perk countdown and the separate raffle reveal date.
    func test_weekOneNotJoinedShowsPerkCountdownAndRevealDate() throws {
        let now = try XCTUnwrap(date("2026-07-31T13:00:00Z"))
        let zeroFeeEndsAt = try XCTUnwrap(date("2026-08-07T13:00:00Z"))
        let revealsAt = try XCTUnwrap(date("2026-08-25T13:00:00Z"))
        let content = MysteryRaffleContent(
            raffle: launchRaffle(zeroFeeEndsAt: zeroFeeEndsAt, prizesRevealAt: revealsAt),
            now: now
        )

        XCTAssertEqual(content.hero.countdown?.target, zeroFeeEndsAt)
        XCTAssertEqual(content.hero.moreOnDateText, TKLocales.MysteryRaffle.moreOn(dayAndMonth(revealsAt)))
    }

    /// Wallets that never synced during the launch window have no perk to count, so the hero
    /// falls back to the date the prizes are revealed instead of rendering no clock at all —
    /// and the pill is still the launch one, since the raffle hasn't opened either.
    func test_preStartPayloadWithoutPerkFallsBackToTheRevealDate() {
        let revealsAt = Date().addingTimeInterval(30 * 86400)
        let content = MysteryRaffleContent(raffle: launchRaffle(zeroFeeEndsAt: nil, prizesRevealAt: revealsAt))

        XCTAssertNil(content.hero.countdown)
        XCTAssertEqual(content.hero.moreOnDateText, TKLocales.MysteryRaffle.moreOn(dayAndMonth(revealsAt)))
        XCTAssertEqual(content.statusBadge?.icon, .fire)
    }

    func test_mainScreenEntryIsHiddenForOfferPayloadWithoutProgress() throws {
        let now = RaffleClock.now
        let raffle = raffle(
            status: .joined,
            startsAt: now.addingTimeInterval(-86400),
            endsAt: now.addingTimeInterval(40 * 86400),
            ticketsTotal: 10,
            zeroFeeEndsAt: nil,
            badgeIconId: "checkmark"
        )
        let presentation = try XCTUnwrap(MysteryRafflePresentation(raffles: [raffle]))

        XCTAssertFalse(presentation.shouldShowMainScreenEntry)
    }

    func test_mainScreenEntryAppearsForLivePayloadWhileBenefitWindowIsOpen() throws {
        let now = RaffleClock.now
        let raffle = liveRaffle(
            status: .joined,
            endsAt: now.addingTimeInterval(20 * 86400),
            ticketsTotal: 10,
            zeroFeeEndsAt: now.addingTimeInterval(86400)
        )
        let presentation = try XCTUnwrap(MysteryRafflePresentation(raffles: [raffle]))

        XCTAssertTrue(presentation.shouldShowMainScreenEntry)
    }

    // MARK: - Live raffle

    /// The regression this mapping exists for: a wallet with no tickets during the live
    /// raffle reports not_joined, and must still get the live layout — ticket counter at
    /// zero, earn sections, raffle-end countdown — not the launch modal.
    func test_liveRafflePayloadWithoutTicketsRendersTheLiveLayout() {
        let endsAt = Date().addingTimeInterval(20 * 86400)
        let content = MysteryRaffleContent(
            raffle: liveRaffle(status: .notJoined, endsAt: endsAt)
        )

        XCTAssertTrue(content.showsTicketsCard)
        XCTAssertEqual(content.tickets.count, "0")
        XCTAssertNotNil(content.tickets.getMoreTitle)
        XCTAssertEqual(content.earnTasks.count, 1)
        XCTAssertEqual(content.hero.countdown?.target, endsAt)
        XCTAssertNil(content.hero.moreOnDateText)
        XCTAssertEqual(content.statusBadge?.icon, .ticket)
    }

    /// A wallet that migrated during the launch week carries its perk window into the live
    /// raffle. The perk clock belongs to the launch modal, so once the payload has sections
    /// to earn from, the hero counts the raffle down — not the perk.
    func test_livePayloadKeepsTheRaffleEndDespiteAnOpenPerkWindow() {
        let endsAt = Date().addingTimeInterval(20 * 86400)
        let content = MysteryRaffleContent(
            raffle: liveRaffle(
                status: .joined,
                endsAt: endsAt,
                zeroFeeEndsAt: Date().addingTimeInterval(2 * 86400)
            )
        )

        XCTAssertEqual(content.hero.countdown?.target, endsAt)
    }

    func test_liveRafflePayloadWithTicketsRendersTheSameLayout() {
        let content = MysteryRaffleContent(raffle: liveRaffle(status: .joined, ticketsTotal: 123))

        XCTAssertTrue(content.showsTicketsCard)
        XCTAssertEqual(content.tickets.count, "123")
        XCTAssertEqual(content.statusBadge?.icon, .ticket)
    }

    /// "Get More" scrolls to the earn-tickets section, so milestones alone don't earn it
    /// the button — they'd leave it scrolling nowhere.
    func test_milestonesAloneShowTheCounterWithoutGetMore() {
        let content = MysteryRaffleContent(raffle: liveRaffle(tasks: [], milestones: [milestone]))

        XCTAssertTrue(content.showsTicketsCard)
        XCTAssertNil(content.tickets.getMoreTitle)
    }

    /// Awaiting the reveal: the raffle is over, so no clock is left to run, but the
    /// payload is still the live one.
    func test_endedPendingPayloadKeepsTheLiveLayoutWithoutCountdown() {
        let content = MysteryRaffleContent(
            raffle: liveRaffle(
                status: .endedPending,
                endsAt: Date().addingTimeInterval(-3600),
                ticketsTotal: 123
            )
        )

        XCTAssertTrue(content.showsTicketsCard)
        XCTAssertNil(content.hero.countdown)
    }

    /// The reveal-pending payload can arrive stripped of its earn sections, exactly like a
    /// results one. The tally the user finished on is the whole point of the screen at that
    /// moment, so it can't be tied to sections that are gone — and the funnel has to keep
    /// reading the raffle, not fall back to the launch modal.
    func test_endedPendingWithoutEarnSectionsKeepsTheTally() {
        let raffle = liveRaffle(
            status: .endedPending,
            endsAt: Date().addingTimeInterval(-3600),
            ticketsTotal: 123,
            tasks: [],
            milestones: []
        )
        let content = MysteryRaffleContent(raffle: raffle)

        XCTAssertTrue(content.showsTicketsCard)
        XCTAssertEqual(content.tickets.count, "123")
        XCTAssertEqual(MysteryRaffleCoordinator.analyticsKind(for: raffle), .active)
    }

    /// A payload with nothing to earn tickets from is the launch modal only while the
    /// wallet hasn't reached an outcome.
    func test_analyticsKindSeparatesTheLaunchFunnelFromTheRaffle() {
        XCTAssertEqual(MysteryRaffleCoordinator.analyticsKind(for: launchRaffle()), .migration)
        XCTAssertEqual(MysteryRaffleCoordinator.analyticsKind(for: liveRaffle()), .active)
        XCTAssertEqual(
            MysteryRaffleCoordinator.analyticsKind(for: liveRaffle(status: .won, tasks: [], milestones: [])),
            .won
        )
        XCTAssertEqual(
            MysteryRaffleCoordinator.analyticsKind(for: liveRaffle(status: .lost, tasks: [], milestones: [])),
            .lost
        )
    }

    // MARK: - Results

    /// Results payloads carry no sections at all, so the final tally has to come from the
    /// outcome rather than from the arrays.
    func test_wonPayloadShowsFinalTallyGlowAndConfetti() {
        let content = MysteryRaffleContent(
            raffle: liveRaffle(
                status: .won,
                endsAt: Date().addingTimeInterval(-86400),
                ticketsTotal: 123,
                tasks: [],
                milestones: []
            )
        )

        XCTAssertTrue(content.showsTicketsCard)
        XCTAssertTrue(content.showsConfetti)
        XCTAssertNil(content.tickets.getMoreTitle)
        XCTAssertNil(content.hero.countdown)
    }

    func test_lostPayloadShowsFinalTallyWithoutConfetti() {
        let content = MysteryRaffleContent(
            raffle: liveRaffle(
                status: .lost,
                endsAt: Date().addingTimeInterval(-86400),
                ticketsTotal: 123,
                tasks: [],
                milestones: []
            )
        )

        XCTAssertTrue(content.showsTicketsCard)
        XCTAssertFalse(content.showsConfetti)
    }

    /// The results hero is the outcome itself: the backend keeps sending `status_badge`,
    /// but the pill has no place above it.
    func test_resultPayloadHasNoStatusBadge() {
        for status in [MultichainRaffleStatus.won, .lost] {
            let content = MysteryRaffleContent(
                raffle: liveRaffle(status: status, endsAt: Date().addingTimeInterval(-86400), tasks: [], milestones: [])
            )

            XCTAssertNil(content.statusBadge, "\(status)")
        }
    }

    /// A perk window that outlives the outcome must not put a running clock or a launch
    /// pill back on the results screen.
    func test_resultPayloadIgnoresALivePerkWindow() {
        let content = MysteryRaffleContent(
            raffle: liveRaffle(
                status: .won,
                endsAt: Date().addingTimeInterval(-86400),
                zeroFeeEndsAt: Date().addingTimeInterval(86400),
                tasks: [],
                milestones: []
            )
        )

        XCTAssertNil(content.hero.countdown)
        XCTAssertNil(content.statusBadge)
    }

    // MARK: - CTA routing

    /// The backend resolves the CTA per state, so the payload — not the phase — picks the
    /// destination.
    func test_ctaRouteFollowsThePayload() {
        XCTAssertEqual(route(payload: "tonkeeper://migrate"), .migrate)
        XCTAssertEqual(route(payload: "https://app.tonkeeper.com/migration"), .migrate)
        XCTAssertEqual(route(payload: "tonkeeper://swap?ft=TON&tt=USDT"), .swap)
    }

    /// A `.link` CTA is the external results page; a deeplink the raffle doesn't own goes
    /// to the generic dispatch; anything unparseable falls back to the qualifying swap
    /// instead of dead-ending the button.
    func test_ctaRouteFallbacks() {
        XCTAssertEqual(route(payload: "https://t.me/tonkeeper", action: .link), .resultsLink)
        XCTAssertEqual(route(payload: "tonkeeper://battery"), .deeplink("tonkeeper://battery"))
        XCTAssertEqual(route(payload: "not a url at all"), .swap)
        XCTAssertEqual(route(payload: ""), .swap)
    }

    func test_ctaRouteAnalyticsActions() {
        XCTAssertEqual(MysteryRaffleCoordinator.CtaRoute.migrate.analyticsAction, .migrate)
        XCTAssertEqual(MysteryRaffleCoordinator.CtaRoute.swap.analyticsAction, .swap)
        XCTAssertEqual(MysteryRaffleCoordinator.CtaRoute.resultsLink.analyticsAction, .resultsLink)
        XCTAssertNil(MysteryRaffleCoordinator.CtaRoute.deeplink("x").analyticsAction)
    }

    // MARK: - FAQ

    /// The launch modal explains the raffle it is teasing, with the reveal date substituted
    /// into the copy rather than hardcoded.
    func test_launchPayloadShowsWeekOneFAQ() throws {
        let now = try XCTUnwrap(date("2026-07-31T13:00:00Z"))
        let zeroFeeEndsAt = try XCTUnwrap(date("2026-08-07T13:00:00Z"))
        let revealsAt = try XCTUnwrap(date("2026-08-25T13:00:00Z"))
        let content = MysteryRaffleContent(
            raffle: launchRaffle(zeroFeeEndsAt: zeroFeeEndsAt, prizesRevealAt: revealsAt),
            now: now
        )

        XCTAssertEqual(content.faq.map(\.id), ["about", "migrate_before", "migrate_after", "fee_end"])
        XCTAssertEqual(content.faq[0].answer, TKLocales.MysteryRaffle.Faq.About.answer(dayAndMonth(revealsAt), 10))
        XCTAssertEqual(
            content.faq[1].question,
            TKLocales.MysteryRaffle.Faq.MigrateBefore.question(dayAndMonth(revealsAt))
        )
        XCTAssertEqual(content.faq[3].answer, TKLocales.MysteryRaffle.Faq.FeeEnd.answer(dayAndMonth(zeroFeeEndsAt)))
    }

    /// Before the reveal is scheduled the launch date the copy talks about is the end of the
    /// perk window — and the hero's "More on" line must name that same day, not the raffle end.
    func test_weekOneFAQAndHeroAgreeOnTheLaunchDateWhenRevealIsNotScheduled() throws {
        let now = try XCTUnwrap(date("2026-07-31T13:00:00Z"))
        let zeroFeeEndsAt = try XCTUnwrap(date("2026-08-07T13:00:00Z"))
        let content = MysteryRaffleContent(
            raffle: launchRaffle(zeroFeeEndsAt: zeroFeeEndsAt, prizesRevealAt: nil),
            now: now
        )

        XCTAssertEqual(content.faq[0].answer, TKLocales.MysteryRaffle.Faq.About.answer(dayAndMonth(zeroFeeEndsAt), 10))
        XCTAssertEqual(content.hero.moreOnDateText, TKLocales.MysteryRaffle.moreOn(dayAndMonth(zeroFeeEndsAt)))
    }

    /// Every week-1 answer is about the perk window; with no window there is nothing to answer.
    func test_launchPayloadWithoutPerkWindowHasNoFAQ() {
        let content = MysteryRaffleContent(raffle: launchRaffle(zeroFeeEndsAt: nil, prizesRevealAt: Date()))

        XCTAssertTrue(content.faq.isEmpty)
    }

    func test_liveRaffleShowsWeekTwoFAQ() {
        let endsAt = Date().addingTimeInterval(20 * 86400)
        let content = MysteryRaffleContent(raffle: liveRaffle(endsAt: endsAt))

        XCTAssertEqual(content.faq.map(\.id), ["earn", "prizes", "end", "winners", "rewards"])
        XCTAssertEqual(content.faq[2].answer, TKLocales.MysteryRaffle.Faq.End.answer(dayAndMonth(endsAt)))
    }

    /// The rewards the FAQ quotes come from the payload it is shown next to: the migration
    /// task's own reward — which differs between the launch week and the raffle proper — and
    /// the richest milestone, not the sum of them.
    func test_weekTwoFAQQuotesTheRewardsFromThePayload() {
        let content = MysteryRaffleContent(
            raffle: liveRaffle(
                tasks: [migrationTask(rewardTickets: 7), task],
                milestones: [milestoneTier(rewardTickets: 25), milestoneTier(rewardTickets: 900)]
            )
        )

        XCTAssertEqual(content.faq[0].answer, TKLocales.MysteryRaffle.Faq.Earn.answer(7, 900))
    }

    /// The launch modal hides the migration task but still quotes its reward, in both the
    /// answer that sells the perk and the one that explains the raffle.
    func test_weekOneFAQQuotesTheMigrationRewardFromThePayload() throws {
        let now = try XCTUnwrap(date("2026-07-31T13:00:00Z"))
        let revealsAt = try XCTUnwrap(date("2026-08-25T13:00:00Z"))
        let content = MysteryRaffleContent(
            raffle: launchRaffle(prizesRevealAt: revealsAt, tasks: [migrationTask(rewardTickets: 12)]),
            now: now
        )

        XCTAssertTrue(content.earnTasks.isEmpty)
        XCTAssertEqual(content.faq[0].answer, TKLocales.MysteryRaffle.Faq.About.answer(dayAndMonth(revealsAt), 12))
        XCTAssertEqual(content.faq[1].answer, TKLocales.MysteryRaffle.Faq.MigrateBefore.answer(12))
    }

    /// Numbers the payload doesn't carry keep the campaign's own — the copy the strings ship
    /// with. A live payload always carries milestones (an empty set reads as the launch phase),
    /// so only the stub-facing entry point falls back on both.
    func test_faqFallsBackToTheCampaignNumbersWithoutAMigrationTask() {
        let content = MysteryRaffleContent(raffle: liveRaffle(tasks: [task]))

        XCTAssertEqual(content.faq[0].answer, TKLocales.MysteryRaffle.Faq.Earn.answer(10, 10))
        XCTAssertEqual(
            MysteryRaffleContent.activeFAQ(endsAt: Date())[0].answer,
            TKLocales.MysteryRaffle.Faq.Earn.answer(10, 1000)
        )
    }

    /// Nothing is left to explain once the raffle is over — on the tally, on the results
    /// screens, and on a payload the backend hasn't caught up with yet.
    func test_endedRafflesHaveNoFAQ() {
        let endsAt = Date().addingTimeInterval(20 * 86400)

        XCTAssertTrue(MysteryRaffleContent(raffle: liveRaffle(status: .endedPending)).faq.isEmpty)
        XCTAssertTrue(MysteryRaffleContent(raffle: liveRaffle(status: .won)).faq.isEmpty)
        XCTAssertTrue(MysteryRaffleContent(raffle: liveRaffle(status: .lost)).faq.isEmpty)
        XCTAssertTrue(
            MysteryRaffleContent(
                raffle: liveRaffle(endsAt: endsAt),
                now: endsAt.addingTimeInterval(60)
            ).faq.isEmpty
        )
    }

    // MARK: - Grouped amounts

    /// The backend groups volume amounts with a plain space, and wrapping on it used to split
    /// "$10 000" into "$10" / "000". Only the in-number spaces are bound; words still wrap.
    func test_groupedAmountsStayOnOneLine() {
        let content = MysteryRaffleContent(
            raffle: liveRaffle(
                tasks: [
                    MultichainRaffleTask(
                        id: "swap",
                        iconId: "swap",
                        title: "Swap $1 000 in volume",
                        subtitle: "Up to 10 000 tickets",
                        rewardTickets: 3,
                        deeplink: nil,
                        done: nil
                    ),
                ],
                milestones: [
                    MultichainRaffleMilestone(
                        id: "trusted",
                        iconId: "keeper",
                        title: "Trusted \u{00B7} $10 000 volume",
                        subtitle: nil,
                        rewardTickets: 20,
                        done: false
                    ),
                ],
                history: [
                    MultichainRaffleHistoryItem(
                        id: "milestone:keeper",
                        awardedAt: Date(),
                        iconId: "keeper",
                        title: "Keeper \u{00B7} $1 000 volume",
                        tickets: 10
                    ),
                ]
            )
        )

        XCTAssertEqual(content.earnTasks.first?.title, "Swap $1\u{00A0}000 in volume")
        XCTAssertEqual(content.earnTasks.first?.subtitle, "Up to 10\u{00A0}000 tickets")
        XCTAssertEqual(content.milestones.first?.title, "Trusted \u{00B7} $10\u{00A0}000 volume")
        XCTAssertEqual(content.history.first?.title, "Keeper \u{00B7} $1\u{00A0}000 volume")
    }

    // MARK: - Fixtures

    /// Same locale-driven day+month form the mapper renders, so the expectation doesn't
    /// depend on the runner's locale.
    private func dayAndMonth(_ date: Date) -> String {
        MysteryRaffleContent.dayMonthFormatter.string(from: date)
    }

    private func date(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }

    private func route(
        payload: String,
        action: MultichainRaffleCTA.Action = .deeplink
    ) -> MysteryRaffleCoordinator.CtaRoute {
        MysteryRaffleCoordinator.ctaRoute(
            for: MultichainRaffleCTA(title: "CTA", action: action, payload: payload),
            deeplinkParser: DeeplinkParser(
                walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation()
            )
        )
    }

    private let task = MultichainRaffleTask(
        id: "swap",
        iconId: "swap",
        title: "Make $100+ in cross-chain swap volume",
        subtitle: nil,
        rewardTickets: 1,
        deeplink: nil,
        done: nil
    )

    private func migrationTask(rewardTickets: Int) -> MultichainRaffleTask {
        MultichainRaffleTask(
            id: "migration",
            iconId: "migrate",
            title: "Migrate assets from your TON wallets",
            subtitle: nil,
            rewardTickets: rewardTickets,
            deeplink: "tonkeeper://migrate",
            done: nil
        )
    }

    private func milestoneTier(rewardTickets: Int) -> MultichainRaffleMilestone {
        MultichainRaffleMilestone(
            id: "tier-\(rewardTickets)",
            iconId: "keeper",
            title: "Tier",
            subtitle: nil,
            rewardTickets: rewardTickets,
            done: false
        )
    }

    private let milestone = MultichainRaffleMilestone(
        id: "keeper",
        iconId: "keeper",
        title: "Keeper",
        subtitle: nil,
        rewardTickets: 10,
        done: false
    )

    /// Launch phase: the raffle hasn't opened and the backend sends no prizes / tasks /
    /// milestones yet, only the benefit cards.
    private func launchRaffle(
        status: MultichainRaffleStatus = .notJoined,
        ticketsTotal: Int = 0,
        zeroFeeEndsAt: Date? = Date().addingTimeInterval(3 * 86400),
        prizesRevealAt: Date? = nil,
        tasks: [MultichainRaffleTask]? = nil
    ) -> MultichainRaffle {
        raffle(
            status: status,
            startsAt: Date().addingTimeInterval(7 * 86400),
            endsAt: Date().addingTimeInterval(40 * 86400),
            ticketsTotal: ticketsTotal,
            zeroFeeEndsAt: zeroFeeEndsAt,
            badgeIconId: status == .joined ? "checkmark" : "fire",
            prizesRevealAt: prizesRevealAt,
            benefitCards: [
                MultichainRaffleBenefitCard(id: "swaps", iconId: "swap", label: "Launch benefit", title: "0% fee", subtitle: nil),
                MultichainRaffleBenefitCard(id: "raffle", iconId: "ticket", label: "Mystery Raffle", title: "10 tickets", subtitle: nil),
            ],
            tasks: tasks ?? [task]
        )
    }

    /// Live raffle: opened, perk window closed, ticket-earning content in the payload.
    private func liveRaffle(
        status: MultichainRaffleStatus = .notJoined,
        endsAt: Date = Date().addingTimeInterval(20 * 86400),
        ticketsTotal: Int = 0,
        zeroFeeEndsAt: Date? = nil,
        tasks: [MultichainRaffleTask]? = nil,
        milestones: [MultichainRaffleMilestone]? = nil,
        history: [MultichainRaffleHistoryItem] = []
    ) -> MultichainRaffle {
        raffle(
            status: status,
            startsAt: Date().addingTimeInterval(-7 * 86400),
            endsAt: endsAt,
            ticketsTotal: ticketsTotal,
            zeroFeeEndsAt: zeroFeeEndsAt,
            badgeIconId: "mystery_raffle",
            tasks: tasks ?? [task],
            milestones: milestones ?? [milestone],
            history: history
        )
    }

    private func raffle(
        status: MultichainRaffleStatus,
        startsAt: Date,
        endsAt: Date,
        ticketsTotal: Int,
        zeroFeeEndsAt: Date?,
        badgeIconId: String,
        prizesRevealAt: Date? = nil,
        benefitCards: [MultichainRaffleBenefitCard] = [],
        tasks: [MultichainRaffleTask] = [],
        milestones: [MultichainRaffleMilestone] = [],
        history: [MultichainRaffleHistoryItem] = []
    ) -> MultichainRaffle {
        MultichainRaffle(
            id: "mystery",
            status: status,
            hero: MultichainRaffleHero(image: "", badgeIconId: badgeIconId),
            title: "Win a share of $100K prize pool",
            subtitle: "",
            startsAt: startsAt,
            endsAt: endsAt,
            prizesRevealAt: prizesRevealAt,
            compactBanner: MultichainRaffleCompactBanner(defaultTitle: "", activeTitle: "", iconId: "ticket"),
            prizesHeader: "",
            statusBadge: "Mystery Raffle",
            benefitCards: benefitCards,
            prizes: [],
            tasks: tasks,
            milestones: milestones,
            cta: MultichainRaffleCTA(title: "CTA", action: .deeplink, payload: ""),
            progress: MultichainRaffleProgress(
                ticketsTotal: ticketsTotal,
                history: history,
                zeroFeeEndsAt: zeroFeeEndsAt
            )
        )
    }
}
