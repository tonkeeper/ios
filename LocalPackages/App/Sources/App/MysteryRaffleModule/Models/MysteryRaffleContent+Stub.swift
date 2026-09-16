import Foundation
import TKLocalize

/// Stub content mirroring the Figma frames, used to drive the design (previews and the
/// dev-menu design-review screen) while no live raffle is loaded. Strings are
/// server-provided and state-resolved in production, so they live only here.
///
/// Artwork is deliberately not bundled: every image slot falls back to the glyph the
/// production layout shows while `hero.image` / prize art is loading.
extension MysteryRaffleContent {
    // MARK: Shared active-state pieces (identical across every active mockup)

    /// Mocked raffle end so the hero countdown ticks live. Recomputed per access (fine for
    /// stubs); production supplies the real end instant.
    private static var mockEndDate: Date {
        Date().addingTimeInterval(2_007_859) // 23 * 86400 + 5 * 3600 + 44 * 60 + 19
    }

    /// Migration-modal date behind the FAQ copy: the perk window closes when the raffle
    /// launches, matching the "Ends in 6 days" countdown in the mockup. Every date the
    /// week-1 mocks name — benefit card, "More on" line, FAQ — is rendered from it, so the
    /// mocked screen stays internally consistent as the stubs are re-evaluated.
    private static var mockZeroFeeEndDate: Date {
        Date().addingTimeInterval(538_459) // 6 * 86400 + 5 * 3600 + 44 * 60 + 19
    }

    private static var mockLaunchDateText: String {
        dayMonthFormatter.string(from: mockZeroFeeEndDate)
    }

    private static var activeHero: RaffleHero {
        RaffleHero(
            icon: .ticketLarge,
            title: "Win a share\nof $100K prize pool",
            subtitle: "Complete tasks, make cross-chain swaps, and earn tickets. More tickets — more chances to win.",
            countdown: RaffleCountdown(target: mockEndDate, prefix: "Ends in")
        )
    }

    private static let activeBadge = RaffleStatusBadge(icon: .ticket, text: "Mystery Raffle")

    /// Full prize set from the Figma mockup — a short stub read as the *entire* carousel
    /// instead of a hint that it scrolls.
    private static var prizes: [RafflePrize] {
        [
            RafflePrize(id: "usdt-10000", image: .symbol(.ticket), title: "$10 000 in USDT", subtitle: "for 1 winner"),
            RafflePrize(id: "pepe", image: .symbol(.ticket), title: "Plush Pepe NFT", subtitle: "for 1 winner"),
            RafflePrize(id: "usdt-1000", image: .symbol(.ticket), title: "$1 000 in USDT", subtitle: "for 20 winners"),
            RafflePrize(id: "usdt-200", image: .symbol(.ticket), title: "$200 in USDT", subtitle: "for 100 winners"),
            RafflePrize(id: "usdt-50", image: .symbol(.ticket), title: "$50 in USDT", subtitle: "for 400 winners"),
            RafflePrize(id: "usdt-20", image: .symbol(.ticket), title: "$20 in USDT", subtitle: "for 1000 winners"),
            RafflePrize(id: "battery-100", image: .symbol(.flash), title: "Big Battery", subtitle: "for 50 winners"),
            RafflePrize(id: "battery-50", image: .symbol(.flash), title: "Medium Battery", subtitle: "for 150 winners"),
            RafflePrize(id: "battery-25", image: .symbol(.flash), title: "Small Battery", subtitle: "for 278 winners"),
        ]
    }

    private static var stubHistory: [RaffleHistoryItem] {
        [
            RaffleHistoryItem(id: "raffle:milestone:senior", icon: .shield, title: "Trusted · $10\u{00A0}000 volume", amountText: "+25 tickets", dateText: "June 22, 10:05"),
            RaffleHistoryItem(id: "raffle:swap:1", icon: .swap, title: "$100 swap", amountText: "+1 ticket", dateText: "June 20, 18:35"),
            RaffleHistoryItem(id: "raffle:task:migration", icon: .trayArrowDown, title: "Assets migration", amountText: "+5 tickets", dateText: "June 20, 17:32"),
        ]
    }

    /// Lost result: the won rows plus one extra swap (4 total).
    private static var stubResultHistoryLost: [RaffleHistoryItem] {
        [
            RaffleHistoryItem(id: "raffle:milestone:senior", icon: .fire, title: "Senior milestone", amountText: "+150 tickets", dateText: "June 22, 10:05"),
            RaffleHistoryItem(id: "raffle:swap:1", icon: .swap, title: "$100 swap", amountText: "+1 ticket", dateText: "June 20, 18:35"),
            RaffleHistoryItem(id: "raffle:swap:2", icon: .swap, title: "$100 swap", amountText: "+1 ticket", dateText: "June 20, 18:35"),
            RaffleHistoryItem(id: "raffle:task:migration", icon: .trayArrowDown, title: "Assets migration", amountText: "+5 tickets", dateText: "June 20, 17:32"),
        ]
    }

    // MARK: Earn-task factories (accessory varies: chevron = actionable, done = completed)

    private static func metaMaskTask(_ accessory: RaffleRowAccessory) -> RaffleEarnTask {
        RaffleEarnTask(id: "metamask", icon: .key, accent: .orange, title: "Import MetaMask and make at least a $100 swap", subtitle: "3 tickets", accessory: accessory)
    }

    private static func migrateTask(_ accessory: RaffleRowAccessory) -> RaffleEarnTask {
        RaffleEarnTask(id: "migrate", icon: .trayArrowDown, accent: .blue, title: "Migrate assets from your TON wallets", subtitle: "5 tickets", accessory: accessory)
    }

    /// Continuous task — always shows a chevron (never "completed").
    private static let swapTask = RaffleEarnTask(id: "swap", icon: .swap, accent: .green, title: "Make $100+ in cross-chain swap volume", subtitle: "1 ticket per every $100 volume", accessory: .chevron)

    // MARK: Milestone sets

    /// Not joined: only the current (Keeper) milestone is highlighted and tappable.
    private static var milestonesNotJoined: [RaffleMilestone] {
        [
            RaffleMilestone(id: "keeper", icon: .wallet, accent: .blue, title: "Keeper · $1 000 volume", subtitle: "+10 bonus tickets", isAchieved: true, accessory: .chevron),
            RaffleMilestone(id: "trusted", icon: .shield, accent: .green, title: "Trusted · $10 000 volume", subtitle: "+25 bonus tickets", isAchieved: false),
            RaffleMilestone(id: "senior", icon: .fire, accent: .orange, title: "Senior · $10 000 volume", subtitle: "+150 bonus tickets", isAchieved: false),
            RaffleMilestone(id: "legend", icon: .rocket, accent: .purple, title: "Legend · $1M volume", subtitle: "+1 000 bonus tickets", isAchieved: false),
        ]
    }

    /// Joined: every milestone achieved, no chevron on any row.
    private static var milestonesJoined: [RaffleMilestone] {
        [
            RaffleMilestone(id: "keeper", icon: .wallet, accent: .blue, title: "Keeper · $1 000 volume", subtitle: "+10 bonus tickets", isAchieved: true),
            RaffleMilestone(id: "trusted", icon: .shield, accent: .green, title: "Trusted · $10 000 volume", subtitle: "+25 bonus tickets", isAchieved: true),
            RaffleMilestone(id: "senior", icon: .fire, accent: .orange, title: "Senior · $10 000 volume", subtitle: "+150 bonus tickets", isAchieved: true),
            RaffleMilestone(id: "legend", icon: .rocket, accent: .purple, title: "Legend · $1M volume", subtitle: "+1 000 bonus tickets", isAchieved: true),
        ]
    }

    // MARK: Builders

    private static func active(
        tickets: String,
        earnTasks: [RaffleEarnTask],
        milestones: [RaffleMilestone],
        history: [RaffleHistoryItem],
        cta: String
    ) -> MysteryRaffleContent {
        MysteryRaffleContent(
            statusBadge: activeBadge,
            hero: activeHero,
            tickets: RaffleTicketsInfo(count: tickets, caption: "Your tickets", getMoreTitle: "Get More"),
            prizesTitle: "More than 2 000 prizes",
            prizes: prizes,
            earnTasks: earnTasks,
            milestones: milestones,
            history: history,
            faq: activeFAQ(endsAt: mockEndDate),
            primaryButton: RaffleActionButton(title: cta),
            showsTicketsCard: true,
            showsConfetti: false
        )
    }

    private static func result(
        title: String,
        subtitle: String,
        showsConfetti: Bool
    ) -> MysteryRaffleContent {
        MysteryRaffleContent(
            statusBadge: nil,
            hero: RaffleHero(
                icon: showsConfetti ? .doneLarge : .ticketLarge,
                title: title,
                subtitle: subtitle
            ),
            tickets: RaffleTicketsInfo(count: "123", caption: "Your final ticket count", getMoreTitle: nil),
            prizesTitle: "Prizes",
            prizes: [],
            earnTasks: [],
            milestones: [],
            history: showsConfetti ? stubHistory : stubResultHistoryLost,
            primaryButton: RaffleActionButton(title: "See All Winners on Telegram"),
            showsTicketsCard: true,
            showsConfetti: showsConfetti
        )
    }

    // MARK: Week-1 migration modal ("Multichain is here")

    /// Benefit cards for the "not joined" migration variant. "Joined" passes `[]`.
    private static var migrationBenefitCards: [RaffleBenefitCard] {
        [
            RaffleBenefitCard(
                id: "swaps",
                icon: .flash,
                accent: .blue,
                label: "Launch benefit",
                title: "Get 0% fee cross-chain swaps this week",
                subtitle: "Trade thousands of assets with 0% fee all this week"
            ),
            RaffleBenefitCard(
                id: "raffle",
                icon: .ticket,
                accent: .blue,
                label: "Mystery Raffle",
                title: "Get 10 mystery tickets",
                subtitle: "More than 2,000 prizes await — the mystery unfolds on \(mockLaunchDateText)"
            ),
        ]
    }

    private static func migration(
        badge: RaffleStatusBadge,
        title: String,
        subtitle: String,
        countdown: RaffleCountdown?,
        moreOnDateText: String?,
        cards: [RaffleBenefitCard],
        cta: String,
        icon: RaffleSymbol = .ticketLarge
    ) -> MysteryRaffleContent {
        MysteryRaffleContent(
            statusBadge: badge,
            hero: RaffleHero(
                icon: icon,
                title: title,
                subtitle: subtitle,
                countdown: countdown,
                moreOnDateText: moreOnDateText
            ),
            tickets: RaffleTicketsInfo(count: "0", caption: "", getMoreTitle: nil),
            prizesTitle: "",
            prizes: [],
            earnTasks: [],
            milestones: [],
            history: [],
            benefitCards: cards,
            faq: migrationFAQ(launchDate: mockZeroFeeEndDate, zeroFeeEndsAt: mockZeroFeeEndDate),
            primaryButton: RaffleActionButton(title: cta),
            showsTicketsCard: false,
            showsConfetti: false
        )
    }

    // MARK: Preview aliases (kept for #Preview blocks)

    static var stubActive: MysteryRaffleContent {
        MysteryRaffleDevState.existing3to5NotJoined.content
    }
}

/// Every modal state from the mockups, surfaced one-per-row in the dev menu so the design
/// can be reviewed without backend phases. Dev-only.
enum MysteryRaffleDevState: String, CaseIterable {
    case existing1wkNotJoined
    case existing1wkJoined
    case existing2to5NotJoined
    case existing2to5Joined
    case existing3to5NotJoined
    case existing3to5Joined
    case new2to5NotJoined
    case new2to5Joined
    case new3to5NotJoined
    case new3to5Joined
    case resultsWon
    case resultsLost

    /// Dev-menu row title.
    var title: String {
        switch self {
        case .existing1wkNotJoined: return "Existing · 1wk · Not joined"
        case .existing1wkJoined: return "Existing · 1wk · Joined"
        case .existing2to5NotJoined: return "Existing · 2-5wk · Not joined"
        case .existing2to5Joined: return "Existing · 2-5wk · Joined"
        case .existing3to5NotJoined: return "Existing · 3-5wk · Not joined"
        case .existing3to5Joined: return "Existing · 3-5wk · Joined"
        case .new2to5NotJoined: return "New · 2-5wk · Not joined"
        case .new2to5Joined: return "New · 2-5wk · Joined"
        case .new3to5NotJoined: return "New · 3-5wk · Not joined"
        case .new3to5Joined: return "New · 3-5wk · Joined"
        case .resultsWon: return "Results · Won"
        case .resultsLost: return "Results · Lost"
        }
    }

    var content: MysteryRaffleContent {
        MysteryRaffleContent.content(for: self)
    }
}

private extension MysteryRaffleContent {
    // swiftlint:disable:next cyclomatic_complexity
    static func content(for state: MysteryRaffleDevState) -> MysteryRaffleContent {
        switch state {
        case .existing1wkNotJoined:
            return migration(
                badge: RaffleStatusBadge(icon: .fire, text: "Multichain is here!"),
                title: "Exclusive\nfor Keeper users",
                subtitle: "Migrate assets from your TON wallet to multichain and unlock benefits.",
                countdown: RaffleCountdown(target: Date().addingTimeInterval(539_059), prefix: "Ends in"), // 6 * 86400 + 5 * 3600 + 44 * 60 + 19
                moreOnDateText: nil,
                cards: migrationBenefitCards,
                cta: "Migrate to Unlock Benefits"
            )
        case .existing1wkJoined:
            return migration(
                badge: RaffleStatusBadge(icon: .checkmarkCircle, text: "You're all set!"),
                title: "Benefits are unlocked",
                subtitle: "You've received 10 mystery tickets. Enjoy 0% fee cross-chain swaps for the next 6 days 05:44:19.",
                countdown: nil,
                moreOnDateText: TKLocales.MysteryRaffle.moreOn(mockLaunchDateText),
                cards: [],
                cta: "Go to Swap",
                icon: .doneLarge
            )
        case .existing2to5NotJoined:
            return active(tickets: "0", earnTasks: [migrateTask(.chevron), swapTask], milestones: milestonesNotJoined, history: [], cta: "Migrate to Get Tickets")
        case .existing2to5Joined:
            return active(tickets: "123", earnTasks: [migrateTask(.done), swapTask], milestones: milestonesJoined, history: stubHistory, cta: "Swap to Get Tickets")
        case .existing3to5NotJoined:
            return active(tickets: "0", earnTasks: [metaMaskTask(.chevron), migrateTask(.chevron), swapTask], milestones: milestonesNotJoined, history: [], cta: "Migrate to Get Tickets")
        case .existing3to5Joined:
            return active(tickets: "123", earnTasks: [metaMaskTask(.done), migrateTask(.done), swapTask], milestones: milestonesJoined, history: stubHistory, cta: "Swap to Get Tickets")
        case .new2to5NotJoined:
            return active(tickets: "0", earnTasks: [swapTask], milestones: milestonesNotJoined, history: [], cta: "Migrate to Get Tickets")
        case .new2to5Joined:
            return active(tickets: "123", earnTasks: [swapTask], milestones: milestonesJoined, history: stubHistory, cta: "Swap to Get Tickets")
        case .new3to5NotJoined:
            return active(tickets: "0", earnTasks: [metaMaskTask(.chevron), swapTask], milestones: milestonesNotJoined, history: [], cta: "Migrate to Get Tickets")
        case .new3to5Joined:
            return active(tickets: "123", earnTasks: [metaMaskTask(.done), swapTask], milestones: milestonesJoined, history: stubHistory, cta: "Swap to Get Tickets")
        case .resultsWon:
            return result(title: "You won a Plush Pepe NFT", subtitle: "Congratulations! Your prize will be credited within 7 days. We'll notify you once it's done.", showsConfetti: true)
        case .resultsLost:
            return result(title: "You didn't win this time", subtitle: "Thanks for making it to the end. See all winners on Telegram.", showsConfetti: false)
        }
    }
}
