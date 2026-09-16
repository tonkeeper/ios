import Foundation
import KeeperCore
import TKLocalize

extension MultichainRaffle {
    var isMigrationPhase: Bool {
        switch status {
        case .notJoined, .joined:
            prizes.isEmpty && milestones.isEmpty
        case .endedPending, .won, .lost:
            false
        }
    }

    /// Tickets the phase pays for migrating, read off the payload's own task list so the FAQ
    /// can't quote a number the tasks on the same screen contradict — the reward changes
    /// between phases (launch week vs. the raffle proper). `icon_id` is the backend's task
    /// kind; ids are per-campaign.
    var migrationRewardTickets: Int? {
        tasks.first { $0.iconId == "migrate" }?.rewardTickets
    }
}

/// Maps the backend `MultichainRaffle` entity onto the view's `MysteryRaffleContent`.
///
/// The payload *is* the phase: the backend scopes `prizes` / `tasks` / `milestones` /
/// `benefit_cards` to the phase it resolved, and `title` / `subtitle` / `hero.image` /
/// `status_badge` / `cta` arrive already resolved for the user's stage. So sections follow
/// the arrays they render, with one exception: the migration modal (no prizes, no milestones)
/// still carries the migration task, and it is the raffle's teaser — hero, benefit cards and
/// CTA — so the earn section, the ticket counter and the history stay off it. `status` is read
/// only where the payload alone can't say it: the results screen (won / lost) and the
/// ended-awaiting-reveal tally, which looks section-less exactly like a results payload.
/// `status`'s not_joined / joined only means "has no tickets yet" / "has tickets", so it
/// never selects a layout.
/// `accent` (tasks/milestones) and prize `shape` are no longer sent by the backend,
/// so the client picks fixed defaults. The status pill's glyph is `hero.badge_icon_id`,
/// which the backend varies per phase (`fire` / `checkmark` / `mystery_raffle`); the hero
/// glyph is only the placeholder behind `hero.image` and stays fixed per outcome.
extension MysteryRaffleContent {
    init(raffle: MultichainRaffle, now: Date = RaffleClock.now) {
        let isResult = raffle.status == .won || raffle.status == .lost
        let isEnded = isResult || raffle.status == .endedPending
        let isMigrationPhase = raffle.isMigrationPhase
        // The migration modal is the raffle's teaser: hero, benefit cards and the CTA. It still
        // arrives carrying the migration task, which belongs to the raffle proper.
        let tasks = isMigrationPhase ? [] : raffle.tasks
        let hasEarnSections = !tasks.isEmpty || !raffle.milestones.isEmpty
        let clock = Self.heroClock(for: raffle, now: now, isMigrationPhase: isMigrationPhase)

        self.init(
            statusBadge: isResult ? nil : raffle.statusBadge.map { text in
                RaffleStatusBadge(icon: raffle.hero.badgeIconId.flatMap(RaffleSymbol.init(iconId:)) ?? .ticket, text: text)
            },
            hero: RaffleHero(
                imageURL: URL(string: raffle.hero.image),
                icon: raffle.status == .won ? .doneLarge : .ticketLarge,
                title: raffle.title,
                subtitle: raffle.subtitle,
                countdown: clock.countdown,
                moreOnDateText: clock.moreOnDateText
            ),
            tickets: RaffleTicketsInfo(
                count: String(raffle.progress?.ticketsTotal ?? 0),
                caption: isResult ? TKLocales.MysteryRaffle.Tickets.finalCount : TKLocales.MysteryRaffle.Tickets.yourTickets,
                getMoreTitle: tasks.isEmpty ? nil : TKLocales.MysteryRaffle.Tickets.getMore
            ),
            prizesTitle: raffle.prizesHeader,
            prizes: raffle.prizes.map { prize in
                RafflePrize(
                    id: prize.id,
                    image: .url(URL(string: prize.image)),
                    title: prize.title,
                    subtitle: prize.subtitle ?? ""
                )
            },
            earnTasks: tasks.map { task in
                RaffleEarnTask(
                    id: task.id,
                    icon: RaffleSymbol(iconId: task.iconId) ?? .ticket,
                    accent: RaffleAccent(iconId: task.iconId) ?? .blue,
                    title: Self.bindingNumberGroups(task.title),
                    subtitle: task.subtitle.map(Self.bindingNumberGroups) ?? Self.ticketsText(task.rewardTickets),
                    accessory: Self.accessory(for: task)
                )
            },
            milestones: Self.milestones(from: raffle.milestones),
            history: (isMigrationPhase ? [] : raffle.progress?.history ?? []).map { item in
                RaffleHistoryItem(
                    id: item.id,
                    icon: RaffleSymbol(iconId: item.iconId) ?? .ticket,
                    title: Self.bindingNumberGroups(item.title),
                    amountText: "+" + Self.ticketsText(item.tickets),
                    dateText: Self.historyDateFormatter.string(from: item.awardedAt)
                )
            },
            benefitCards: raffle.benefitCards.map { card in
                RaffleBenefitCard(
                    id: card.id,
                    icon: RaffleSymbol(iconId: card.iconId) ?? .ticket,
                    accent: .blue,
                    label: card.label,
                    title: card.title,
                    subtitle: card.subtitle ?? "",
                    imageURL: card.imageURL.flatMap(URL.init(string:))
                )
            },
            faq: Self.faq(for: raffle, now: now, isMigrationPhase: isMigrationPhase, isEnded: isEnded),
            primaryButton: RaffleActionButton(title: raffle.cta.title),
            showsTicketsCard: isEnded || hasEarnSections,
            showsConfetti: raffle.status == .won
        )
    }

    // MARK: - Accessory rule

    /// Chevron when a task carries a deeplink (tappable), done-check when completed.
    private static func accessory(for task: MultichainRaffleTask) -> RaffleRowAccessory {
        if task.done == true {
            return .done
        }
        return task.deeplink != nil ? .chevron : .none
    }

    /// Chevron marks the current (first not-yet-done) milestone — that row alone is
    /// tappable and routes to swap; the rest carry no accessory (achieved ones render
    /// their own checkmark from `isAchieved`, see `RaffleMilestoneRow`).
    private static func milestones(from milestones: [MultichainRaffleMilestone]) -> [RaffleMilestone] {
        let currentIndex = milestones.firstIndex { $0.done != true }
        return milestones.enumerated().map { index, milestone in
            RaffleMilestone(
                id: milestone.id,
                icon: RaffleSymbol(iconId: milestone.iconId) ?? .ticket,
                accent: RaffleAccent(iconId: milestone.iconId) ?? .blue,
                title: Self.bindingNumberGroups(milestone.title),
                subtitle: milestone.subtitle.map(Self.bindingNumberGroups) ?? Self.ticketsText(milestone.rewardTickets),
                isAchieved: milestone.done ?? false,
                accessory: index == currentIndex ? .chevron : .none
            )
        }
    }

    // MARK: - Tickets / date formatting

    /// Backend copy groups volume amounts with a plain space ("Trusted · $10 000 volume"),
    /// and a wrap on that space splits the number across lines. Bind the in-number spaces so the
    /// row breaks between words instead.
    private static func bindingNumberGroups(_ text: String) -> String {
        guard text.contains(" ") else { return text }
        var characters = Array(text)
        guard characters.count > 2 else { return text }
        for index in 1 ..< (characters.count - 1) where characters[index] == " " {
            guard characters[index - 1].isNumber, characters[index + 1].isNumber else { continue }
            characters[index] = "\u{00A0}"
        }
        return String(characters)
    }

    private static func ticketsText(_ count: Int) -> String {
        count == 1 ? TKLocales.MysteryRaffle.Tickets.Count.one : TKLocales.MysteryRaffle.Tickets.Count.other(count)
    }

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, HH:mm"
        return formatter
    }()

    // MARK: - FAQ

    /// Client-side FAQ — the backend payload carries no `faq`.
    private static func faq(
        for raffle: MultichainRaffle,
        now: Date,
        isMigrationPhase: Bool,
        isEnded: Bool
    ) -> [RaffleFAQItem] {
        guard !isEnded, now < raffle.endsAt else { return [] }
        guard isMigrationPhase else {
            return activeFAQ(
                endsAt: raffle.endsAt,
                migrationTickets: raffle.migrationRewardTickets,
                // "Up to N bonus tickets" is the richest single milestone, not their sum:
                // milestones are tiers of the same swap volume, and the copy quotes the top one.
                milestoneTickets: raffle.milestones.map(\.rewardTickets).max()
            )
        }
        guard
            let zeroFeeEndsAt = raffle.progress?.zeroFeeEndsAt,
            let launchDate = migrationLaunchDate(for: raffle)
        else { return [] }
        return migrationFAQ(
            launchDate: launchDate,
            zeroFeeEndsAt: zeroFeeEndsAt,
            migrationTickets: raffle.migrationRewardTickets
        )
    }

    /// The launch instant the migration modal talks about — the raffle's scheduled reveal, or
    /// the perk window it is selling when the reveal isn't scheduled yet. The hero's "More on"
    /// line and the FAQ resolve it the same way so the screen never names two launch dates.
    private static func migrationLaunchDate(for raffle: MultichainRaffle) -> Date? {
        raffle.prizesRevealAt ?? raffle.progress?.zeroFeeEndsAt
    }

    /// Week-1 set, shown on the migration modal. Also drives the dev-menu stubs.
    ///
    /// A nil ticket count means the payload carries no migration task to quote (the dev-menu
    /// stubs, or a phase that dropped it); the campaign's own migration reward stands in.
    /// `migrate_after` keeps its literal: the reward the *next* phase will pay isn't in this
    /// payload.
    static func migrationFAQ(launchDate: Date, zeroFeeEndsAt: Date, migrationTickets: Int? = nil) -> [RaffleFAQItem] {
        let faq = TKLocales.MysteryRaffle.Faq.self
        let launch = dayMonthFormatter.string(from: launchDate)
        let tickets = migrationTickets ?? 10
        return [
            RaffleFAQItem(id: "about", question: faq.About.question, answer: faq.About.answer(launch, tickets)),
            RaffleFAQItem(
                id: "migrate_before",
                question: faq.MigrateBefore.question(launch),
                answer: faq.MigrateBefore.answer(tickets)
            ),
            RaffleFAQItem(
                id: "migrate_after",
                question: faq.MigrateAfter.question(launch),
                answer: faq.MigrateAfter.answer
            ),
            RaffleFAQItem(
                id: "fee_end",
                question: faq.FeeEnd.question,
                answer: faq.FeeEnd.answer(dayMonthFormatter.string(from: zeroFeeEndsAt))
            ),
        ]
    }

    /// Week-2-and-later set, shown while the raffle itself runs. Also drives the dev-menu stubs.
    /// Nil counts fall back the same way as `migrationFAQ`'s — the migration reward is the
    /// campaign's 10 in either phase, which is what the migration offer itself advertises.
    static func activeFAQ(endsAt: Date, migrationTickets: Int? = nil, milestoneTickets: Int? = nil) -> [RaffleFAQItem] {
        let faq = TKLocales.MysteryRaffle.Faq.self
        return [
            RaffleFAQItem(
                id: "earn",
                question: faq.Earn.question,
                answer: faq.Earn.answer(migrationTickets ?? 10, milestoneTickets ?? 1000)
            ),
            RaffleFAQItem(id: "prizes", question: faq.Prizes.question, answer: faq.Prizes.answer),
            RaffleFAQItem(
                id: "end",
                question: faq.End.question,
                answer: faq.End.answer(dayMonthFormatter.string(from: endsAt))
            ),
            RaffleFAQItem(id: "winners", question: faq.Winners.question, answer: faq.Winners.answer),
            RaffleFAQItem(id: "rewards", question: faq.Rewards.question, answer: faq.Rewards.answer),
        ]
    }

    // MARK: - Hero clock

    /// What the hero counts, and the date it points at when there is a second one worth
    /// showing.
    ///
    /// The migration modal has two: the perk window it is selling, which is the clock, and the
    /// reveal the raffle is still waiting for, which is the "more on" line. The raffle proper
    /// has one — its own end — even for a wallet whose perk is still running. Nothing is left
    /// to run once the raffle is over.
    private static func heroClock(
        for raffle: MultichainRaffle,
        now: Date,
        isMigrationPhase: Bool
    ) -> (countdown: RaffleCountdown?, moreOnDateText: String?) {
        guard raffle.status != .won, raffle.status != .lost, now < raffle.endsAt else { return (nil, nil) }
        if isMigrationPhase {
            let revealsOn = TKLocales.MysteryRaffle.moreOn(
                dayMonthFormatter.string(from: migrationLaunchDate(for: raffle) ?? raffle.endsAt)
            )
            if let zeroFeeEndsAt = raffle.progress?.zeroFeeEndsAt, now < zeroFeeEndsAt {
                return (countdown(to: zeroFeeEndsAt), revealsOn)
            }
            return (nil, revealsOn)
        }
        let revealsOn = TKLocales.MysteryRaffle.moreOn(
            dayMonthFormatter.string(from: raffle.prizesRevealAt ?? raffle.endsAt)
        )
        guard raffle.startsAt <= now else { return (nil, revealsOn) }
        return (countdown(to: raffle.endsAt), nil)
    }

    private static func countdown(to target: Date) -> RaffleCountdown {
        RaffleCountdown(target: target, prefix: TKLocales.MysteryRaffle.Countdown.endsIn)
    }

    /// Day + month, in the locale's own order — "August 25", "25 августа". Shared by the
    /// hero's "More on …" line and the FAQ so one screen shows one date form.
    static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter
    }()
}

/// Formats "<prefix> N days HH:MM:SS" from `now` to `end` (clamped at zero); the days
/// segment is dropped once under a day. Shared by the live-ticking hero view and this
/// backend snapshot mapper.
func raffleCountdownText(to end: Date, now: Date, prefix: String) -> String {
    let remaining = Int(max(0, end.timeIntervalSince(now)))
    let clock = String(
        format: "%02d:%02d:%02d",
        (remaining % 86400) / 3600,
        (remaining % 3600) / 60,
        remaining % 60
    )
    let days = remaining / 86400
    guard days > 0 else { return "\(prefix) \(clock)" }
    let dayWord = days == 1 ? TKLocales.MysteryRaffle.Countdown.day : TKLocales.MysteryRaffle.Countdown.days
    return "\(prefix) \(days) \(dayWord) \(clock)"
}

// MARK: - Icon resolution: icon_id → RaffleSymbol

private extension RaffleAccent {
    init?(iconId: String) {
        switch iconId {
        case "migrate", "keeper": self = .blue
        case "swap", "trusted": self = .green
        case "metamask", "senior": self = .orange
        case "legend": self = .purple
        default: return nil
        }
    }
}

private extension RaffleSymbol {
    /// Resolves a backend glyph id (semantic slug) to a bundled symbol. Returns nil
    /// for unknown ids so callers can pick a contextual fallback.
    /// Slug vocabulary confirmed from the live endpoint 2026-06-22.
    /// TODO(assets): `metamask` has no dedicated glyph — using `.key` placeholder.
    init?(iconId: String) {
        switch iconId {
        case "mystery_raffle", "ticket": self = .ticket
        case "checkmark": self = .checkmarkCircle
        case "fire": self = .fire
        case "flash": self = .flash
        case "metamask": self = .key
        case "migrate": self = .trayArrowDown
        case "swap": self = .swap
        case "keeper": self = .wallet
        case "trusted": self = .shield
        case "senior": self = .fire
        case "legend": self = .rocket
        default: return nil
        }
    }
}
