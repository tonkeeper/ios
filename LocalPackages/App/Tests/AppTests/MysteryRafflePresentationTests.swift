@testable import App
import Foundation
@testable import KeeperCore
import TKLocalize
import XCTest

final class MysteryRafflePresentationTests: XCTestCase {
    func test_ticketsRaffleSwitchesToActiveTitleWithTickets() {
        let empty = MysteryRafflePresentation(raffle: raffle(id: "mystery_raffle", ticketsTotal: 0))
        let withTickets = MysteryRafflePresentation(raffle: raffle(id: "mystery_raffle", ticketsTotal: 5))

        XCTAssertEqual(empty.compactTitle, "Join")
        XCTAssertNil(empty.badgeText)
        XCTAssertEqual(withTickets.compactTitle, "Active")
        XCTAssertEqual(withTickets.badgeText, TKLocales.MysteryRaffle.Tickets.Count.other(5))
    }

    func test_leaderboardRaffleCountsPointsInsteadOfTickets() {
        let noPoints = MysteryRafflePresentation(raffle: raffle(id: "dinner_with_trump", ticketsTotal: 0, points: 0))
        let withPoints = MysteryRafflePresentation(raffle: raffle(id: "dinner_with_trump", ticketsTotal: 0, points: 1234.5))

        XCTAssertEqual(noPoints.compactTitle, "Join")
        XCTAssertNil(noPoints.badgeText)
        XCTAssertEqual(withPoints.compactTitle, "Active")
        XCTAssertEqual(withPoints.badgeText, TKLocales.MysteryRaffle.Points.Count.other(AmountFormatter().format(decimal: 1234.5)))
    }

    func test_walletListsRafflesWithoutLeaderboardAndTradeListsLeaderboardOnesUntilTheyEnd() {
        let now = Date()
        let endsAt = now.addingTimeInterval(3600)
        let raffles = [
            raffle(id: "mystery_raffle", ticketsTotal: 5, endsAt: endsAt),
            raffle(id: "dinner_with_trump", ticketsTotal: 0, points: 13.4, endsAt: endsAt),
            raffle(id: "next_raffle", ticketsTotal: 0, endsAt: endsAt),
        ]

        let live = MysteryRafflePresentation.all(from: raffles, now: now)
        let ended = MysteryRafflePresentation.all(from: raffles, now: endsAt)

        XCTAssertEqual(live.filter(\.shouldShowWalletEntry).map(\.raffle.id), ["mystery_raffle", "next_raffle"])
        XCTAssertEqual(ended.filter(\.shouldShowWalletEntry).map(\.raffle.id), ["mystery_raffle", "next_raffle"])
        XCTAssertEqual(live.filter(\.shouldShowTradeEntry).map(\.raffle.id), ["dinner_with_trump"])
        XCTAssertTrue(ended.filter(\.shouldShowTradeEntry).isEmpty)
    }

    func test_compactSymbolFollowsTheIconIdAndFallsBackToTheTicket() {
        XCTAssertEqual(MysteryRafflePresentation(raffle: raffle(id: "dinner_with_trump", ticketsTotal: 0, iconId: "dinner")).compactSymbol, .dinner)
        XCTAssertEqual(MysteryRafflePresentation(raffle: raffle(id: "mystery_raffle", ticketsTotal: 0, iconId: "ticket")).compactSymbol, .ticket)
        XCTAssertEqual(MysteryRafflePresentation(raffle: raffle(id: "next_raffle", ticketsTotal: 0, iconId: "unknown")).compactSymbol, .ticket)
    }

    private func raffle(
        id: String,
        ticketsTotal: Int,
        points: Decimal? = nil,
        iconId: String = "ticket",
        endsAt: Date = Date().addingTimeInterval(86400)
    ) -> MultichainRaffle {
        MultichainRaffle(
            id: id,
            status: .joined,
            hero: MultichainRaffleHero(image: "", badgeIconId: nil),
            title: "",
            subtitle: "",
            startsAt: Date().addingTimeInterval(-86400),
            endsAt: endsAt,
            prizesRevealAt: nil,
            compactBanner: MultichainRaffleCompactBanner(defaultTitle: "Join", activeTitle: "Active", iconId: iconId),
            prizesHeader: "",
            statusBadge: nil,
            prizes: [MultichainRafflePrize(id: "prize", image: "", title: "", subtitle: nil)],
            tasks: [],
            milestones: [],
            cta: MultichainRaffleCTA(title: "", action: .deeplink, payload: ""),
            progress: MultichainRaffleProgress(ticketsTotal: ticketsTotal, history: []),
            leaderboard: points.map { MultichainRaffleLeaderboard(points: $0) }
        )
    }
}
