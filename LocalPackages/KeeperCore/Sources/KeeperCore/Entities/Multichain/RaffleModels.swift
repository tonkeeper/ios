import Foundation

// MARK: - Raffle

/// Promo raffle: backend-driven content plus optional per-wallet progress.
/// Mirrors the `Raffle` graph of the Multichain backend; the per-wallet
/// `progress` and the task/milestone `done` flags are populated only by the
/// per-wallet endpoint (`getWalletRaffles`).
public struct MultichainRaffle: Equatable, Sendable, Identifiable {
    public let id: String
    /// Per-wallet relationship to the raffle. Not a lifecycle stage — timing
    /// (`startsAt` / `endsAt` / `prizesRevealAt`) drives upcoming/active/awaiting-reveal
    /// layout; this only distinguishes not-yet-joined/joined from the final won/lost.
    public let status: MultichainRaffleStatus
    public let hero: MultichainRaffleHero
    public let title: String
    public let subtitle: String
    public let startsAt: Date
    public let endsAt: Date
    public let prizesRevealAt: Date?
    public let compactBanner: MultichainRaffleCompactBanner
    public let prizesHeader: String
    /// Short state-dependent label shown above the hero (e.g. "Active", "You won").
    public let statusBadge: String?
    public let benefitCards: [MultichainRaffleBenefitCard]
    public let prizes: [MultichainRafflePrize]
    public let tasks: [MultichainRaffleTask]
    public let milestones: [MultichainRaffleMilestone]
    public let cta: MultichainRaffleCTA
    public let progress: MultichainRaffleProgress?
    public let banner: MultichainRaffleBanner?
    /// Onboarding-style stories attached to the raffle; the active phase can override them.
    public let stories: [MultichainRaffleStory]

    public init(
        id: String,
        status: MultichainRaffleStatus,
        hero: MultichainRaffleHero,
        title: String,
        subtitle: String,
        startsAt: Date,
        endsAt: Date,
        prizesRevealAt: Date?,
        compactBanner: MultichainRaffleCompactBanner,
        prizesHeader: String,
        statusBadge: String?,
        benefitCards: [MultichainRaffleBenefitCard] = [],
        prizes: [MultichainRafflePrize],
        tasks: [MultichainRaffleTask],
        milestones: [MultichainRaffleMilestone],
        cta: MultichainRaffleCTA,
        progress: MultichainRaffleProgress?,
        banner: MultichainRaffleBanner? = nil,
        stories: [MultichainRaffleStory] = []
    ) {
        self.id = id
        self.status = status
        self.hero = hero
        self.statusBadge = statusBadge
        self.title = title
        self.subtitle = subtitle
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.prizesRevealAt = prizesRevealAt
        self.compactBanner = compactBanner
        self.prizesHeader = prizesHeader
        self.benefitCards = benefitCards
        self.prizes = prizes
        self.tasks = tasks
        self.milestones = milestones
        self.cta = cta
        self.progress = progress
        self.banner = banner
        self.stories = stories
    }
}

/// Onboarding-style story attached to a raffle: pages are rendered by the shared
/// stories UI, but arrive inline with the raffle instead of the stories endpoint.
public struct MultichainRaffleStory: Equatable, Sendable, Identifiable {
    public let id: String
    public let pages: [MultichainRaffleStoryPage]

    public init(id: String, pages: [MultichainRaffleStoryPage]) {
        self.id = id
        self.pages = pages
    }
}

public struct MultichainRaffleStoryPage: Equatable, Sendable {
    public let title: String
    public let description: String
    public let image: String
    public let buttons: [MultichainRaffleCTA]

    public init(title: String, description: String, image: String, buttons: [MultichainRaffleCTA] = []) {
        self.title = title
        self.description = description
        self.image = image
        self.buttons = buttons
    }
}

/// Per-wallet relationship to the raffle.
public enum MultichainRaffleStatus: String, Equatable, Sendable {
    case notJoined
    case joined
    case endedPending
    case won
    case lost
}

public struct MultichainRaffleHero: Equatable, Sendable {
    /// Remote illustration URL.
    public let image: String
    /// Client-rendered glyph id.
    public let badgeIconId: String?

    public init(image: String, badgeIconId: String?) {
        self.image = image
        self.badgeIconId = badgeIconId
    }
}

/// Entry rendered in the wallet list.
public struct MultichainRaffleCompactBanner: Equatable, Sendable {
    /// Title when the user has no tickets.
    public let defaultTitle: String
    /// Title when the user has tickets.
    public let activeTitle: String
    public let iconId: String

    public init(defaultTitle: String, activeTitle: String, iconId: String) {
        self.defaultTitle = defaultTitle
        self.activeTitle = activeTitle
        self.iconId = iconId
    }
}

public struct MultichainRaffleBanner: Equatable, Sendable {
    public let title: String
    public let description: String?
    public let imageURL: String
    public let button: MultichainRaffleCTA

    public init(title: String, description: String?, imageURL: String, button: MultichainRaffleCTA) {
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.button = button
    }
}

/// Static promo card shown alongside the raffle.
public struct MultichainRaffleBenefitCard: Equatable, Sendable, Identifiable {
    public let id: String
    /// Client-rendered icon id.
    public let iconId: String
    public let label: String
    public let title: String
    public let subtitle: String?
    /// Optional artwork rendered on the card.
    public let imageURL: String?

    public init(id: String, iconId: String, label: String, title: String, subtitle: String?, imageURL: String? = nil) {
        self.id = id
        self.iconId = iconId
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
    }
}

public struct MultichainRafflePrize: Equatable, Sendable, Identifiable {
    public let id: String
    public let image: String
    public let title: String
    public let subtitle: String?

    public init(id: String, image: String, title: String, subtitle: String?) {
        self.id = id
        self.image = image
        self.title = title
        self.subtitle = subtitle
    }
}

public struct MultichainRaffleTask: Equatable, Sendable, Identifiable {
    public let id: String
    public let iconId: String
    public let title: String
    public let subtitle: String?
    public let rewardTickets: Int
    public let deeplink: String?
    /// Populated only by the per-wallet endpoint.
    public let done: Bool?

    public init(
        id: String,
        iconId: String,
        title: String,
        subtitle: String?,
        rewardTickets: Int,
        deeplink: String?,
        done: Bool?
    ) {
        self.id = id
        self.iconId = iconId
        self.title = title
        self.subtitle = subtitle
        self.rewardTickets = rewardTickets
        self.deeplink = deeplink
        self.done = done
    }
}

public struct MultichainRaffleMilestone: Equatable, Sendable, Identifiable {
    public let id: String
    public let iconId: String
    public let title: String
    public let subtitle: String?
    public let rewardTickets: Int
    /// Populated only by the per-wallet endpoint.
    public let done: Bool?

    public init(
        id: String,
        iconId: String,
        title: String,
        subtitle: String?,
        rewardTickets: Int,
        done: Bool?
    ) {
        self.id = id
        self.iconId = iconId
        self.title = title
        self.subtitle = subtitle
        self.rewardTickets = rewardTickets
        self.done = done
    }
}

/// Bottom button, picked by the backend per user state.
public struct MultichainRaffleCTA: Equatable, Sendable {
    public enum Action: String, Equatable, Sendable {
        case deeplink
        case link
    }

    public let title: String
    public let action: Action
    public let payload: String

    public init(title: String, action: Action, payload: String) {
        self.title = title
        self.action = action
        self.payload = payload
    }
}

public struct MultichainRaffleHistoryItem: Equatable, Sendable, Identifiable {
    /// `{reason_kind}:{reason_id}`.
    public let id: String
    public let awardedAt: Date
    public let iconId: String
    public let title: String
    public let tickets: Int

    public init(id: String, awardedAt: Date, iconId: String, title: String, tickets: Int) {
        self.id = id
        self.awardedAt = awardedAt
        self.iconId = iconId
        self.title = title
        self.tickets = tickets
    }
}

/// The actual prize awarded — may differ from the advertised `prizes[]` entry.
public struct MultichainRaffleWinningPrize: Equatable, Sendable {
    public let title: String
    public let image: String

    public init(title: String, image: String) {
        self.title = title
        self.image = image
    }
}

/// Per-wallet aggregate.
public struct MultichainRaffleProgress: Equatable, Sendable {
    public let ticketsTotal: Int
    public let history: [MultichainRaffleHistoryItem]
    public let winningPrize: MultichainRaffleWinningPrize?
    /// Optional, defaults client-side if absent.
    public let prizeDeliveryDays: Int?
    /// Zero-fee perk expiry; only set for wallets that first synced via v2 during
    /// the raffle's first 7 days. Doubles as the "new user, raffle's first week"
    /// signal for the main-screen entry point.
    public let zeroFeeEndsAt: Date?

    public init(
        ticketsTotal: Int,
        history: [MultichainRaffleHistoryItem],
        winningPrize: MultichainRaffleWinningPrize? = nil,
        prizeDeliveryDays: Int? = nil,
        zeroFeeEndsAt: Date? = nil
    ) {
        self.ticketsTotal = ticketsTotal
        self.history = history
        self.winningPrize = winningPrize
        self.prizeDeliveryDays = prizeDeliveryDays
        self.zeroFeeEndsAt = zeroFeeEndsAt
    }
}
