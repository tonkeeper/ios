import Foundation
import TKUIKit
import UIKit

// MARK: - Symbols

/// All icons used by the raffle screens.
///
/// NOTE: the feature is fully backend-driven — the backend sends icon asset
/// names (or URLs) and the client resolves them. The `ticket / fire / rocket /
/// shield` glyphs are the Figma-designed 28pt icons exported into
/// `TKUIKitResources`. There is no designed 84pt variant of `ticket / done`, so
/// the "Large" cases reuse the vector 28pt glyphs; they scale crisply and only
/// show as the hero fallback when `hero.image` is missing or fails to load.
enum RaffleSymbol {
    case ticketLarge // hero fallback — scaled ic-ticket-28
    case doneLarge // hero fallback — ic-donemark-28
    case ticket // ic-ticket-28
    case key // ic-key-28
    case swap // ic-swap-horizontal-alternative-28
    case wallet // ic-wallet-28
    case shield // ic-shield-28
    case fire // ic-fire-28
    case rocket // ic-rocket-28
    case donemark // ic-donemark-otline-28
    case checkmarkCircle // ic-checkmark-circle-28
    case flash // ic-flash-16
    case trayArrowDown // ic-tray-arrow-down-28

    var image: UIImage {
        switch self {
        case .ticketLarge: return .TKUIKit.Icons.Size28.ticket
        case .doneLarge: return .TKUIKit.Icons.Size28.donemark
        case .ticket: return .TKUIKit.Icons.Size28.ticket
        case .key: return .TKUIKit.Icons.Size28.key
        case .swap: return .TKUIKit.Icons.Size28.swapHorizontalAlternative
        case .wallet: return .TKUIKit.Icons.Size28.wallet
        case .shield: return .TKUIKit.Icons.Size28.shield
        case .fire: return .TKUIKit.Icons.Size28.fire
        case .rocket: return .TKUIKit.Icons.Size28.rocket
        case .donemark: return .TKUIKit.Icons.Size28.donemarkOutline
        case .checkmarkCircle: return .TKUIKit.Icons.Size32.checkmarkCircle
        case .flash: return .TKUIKit.Icons.Size16.flash
        case .trayArrowDown: return .TKUIKit.Icons.Size28.trayArrowDown
        }
    }
}

// MARK: - Accent

/// Tint used for the rounded icon badges. Maps to TKUIKit accent tokens.
enum RaffleAccent {
    case blue
    case green
    case orange
    case purple

    var color: TKColor {
        switch self {
        case .blue: return .accentBlue
        case .green: return .accentGreen
        case .orange: return .accentOrange
        case .purple: return .accentPurple
        }
    }
}

// MARK: - Image source

/// Backend sends either a bundled icon name or a remote URL (prize art / NFT).
enum RaffleImageSource {
    case symbol(RaffleSymbol)
    case url(URL?)
}

// MARK: - Content pieces

/// Live countdown line under the hero subtitle ("Ends in 6 days 05:44:19"). The view ticks
/// per-second to `target` via `TimelineView`, so it stays live as backend state changes.
struct RaffleCountdown {
    let target: Date
    let prefix: String
}

struct RaffleHero {
    /// Remote hero illustration. When present it replaces the bundled glyph;
    /// `icon` is the fallback while it loads / when the URL is missing or fails.
    let imageURL: URL?
    let icon: RaffleSymbol
    let title: String
    let subtitle: String
    /// Live per-second countdown shown under the subtitle; `nil` hides it.
    let countdown: RaffleCountdown?
    /// Pre-formatted "More on 25 August" line on the week-1 modal
    /// (the raffle's `prizes_reveal_at` date). `nil` on every other screen.
    let moreOnDateText: String?

    init(
        imageURL: URL? = nil,
        icon: RaffleSymbol,
        title: String,
        subtitle: String,
        countdown: RaffleCountdown? = nil,
        moreOnDateText: String? = nil
    ) {
        self.imageURL = imageURL
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.countdown = countdown
        self.moreOnDateText = moreOnDateText
    }
}

struct RaffleTicketsInfo {
    let count: String
    let caption: String
    /// "Get More" CTA — present only while the raffle is active.
    let getMoreTitle: String?
}

struct RafflePrize: Identifiable {
    /// Backend prize id — a fresh `UUID()` here would give SwiftUI a new identity
    /// on every content refresh, breaking `RafflePrizesRow`'s stable scroll position
    /// and one-shot reveal animation for prizes that haven't actually changed.
    let id: String
    let image: RaffleImageSource
    let title: String
    let subtitle: String
}

enum RaffleRowAccessory: Equatable {
    case done
    case chevron
    case none
}

struct RaffleEarnTask: Identifiable {
    /// Backend task id — a fresh `UUID()` here would give SwiftUI a new identity
    /// on every content refresh, resetting scroll position and row state.
    let id: String
    let icon: RaffleSymbol
    let accent: RaffleAccent
    let title: String
    let subtitle: String
    let accessory: RaffleRowAccessory
}

struct RaffleMilestone: Identifiable {
    /// Backend milestone id — a fresh `UUID()` here would give SwiftUI a new identity
    /// on every content refresh, resetting row state like prizes and earn tasks.
    let id: String
    let icon: RaffleSymbol
    let accent: RaffleAccent
    let title: String
    let subtitle: String
    let isAchieved: Bool
    /// Trailing accessory. `.chevron` marks the current (next, actionable) milestone
    /// — that row becomes tappable and routes to the same action as the earn tasks.
    let accessory: RaffleRowAccessory

    init(
        id: String,
        icon: RaffleSymbol,
        accent: RaffleAccent,
        title: String,
        subtitle: String,
        isAchieved: Bool,
        accessory: RaffleRowAccessory = .none
    ) {
        self.id = id
        self.icon = icon
        self.accent = accent
        self.title = title
        self.subtitle = subtitle
        self.isAchieved = isAchieved
        self.accessory = accessory
    }
}

struct RaffleHistoryItem: Identifiable {
    /// Backend history entry id — a fresh `UUID()` here would give SwiftUI a new
    /// identity on every content refresh, resetting scroll position.
    let id: String
    let icon: RaffleSymbol
    let title: String
    let amountText: String
    let dateText: String
}

struct RaffleActionButton {
    let title: String
}

/// A benefit card in the "Multichain is here" launch modal: accent icon + uppercase
/// label + title + subtitle, with optional art on the trailing edge.
struct RaffleBenefitCard: Identifiable {
    /// Backend benefit card id — a fresh `UUID()` here would give SwiftUI a new
    /// identity on every content refresh even when card data is unchanged.
    let id: String
    let icon: RaffleSymbol
    let accent: RaffleAccent
    /// Uppercase eyebrow, e.g. "LAUNCH BENEFIT" / "MYSTERY RAFFLE".
    let label: String
    let title: String
    let subtitle: String
    /// Trailing decorative art; `nil` renders the card without it.
    let imageURL: URL?

    init(
        id: String,
        icon: RaffleSymbol,
        accent: RaffleAccent,
        label: String,
        title: String,
        subtitle: String,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.icon = icon
        self.accent = accent
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
    }
}

/// Pill above the hero title ("Early Access" / "You're in!" / "Mystery Raffle").
/// Backend-driven (`status_badge`), state-resolved per user stage.
struct RaffleStatusBadge {
    /// Optional leading glyph; `nil` renders a text-only pill.
    let icon: RaffleSymbol?
    let text: String
    let accent: RaffleAccent

    init(icon: RaffleSymbol?, text: String, accent: RaffleAccent = .blue) {
        self.icon = icon
        self.text = text
        self.accent = accent
    }
}

/// One expandable FAQ row. Question and answer arrive fully formatted from the mapper,
/// dates already substituted.
struct RaffleFAQItem: Identifiable {
    /// Stable content slug ("about" / "earn" / …) — a fresh `UUID()` here would give
    /// SwiftUI a new identity on every content refresh, collapsing an open row.
    let id: String
    let question: String
    let answer: String
}

// MARK: - Screen content

struct MysteryRaffleContent {
    /// Pill above the title; `nil` hides it.
    let statusBadge: RaffleStatusBadge?
    let hero: RaffleHero
    let tickets: RaffleTicketsInfo
    /// Prizes section heading, e.g. "More than 2 000 prizes".
    let prizesTitle: String
    let prizes: [RafflePrize]
    let earnTasks: [RaffleEarnTask]
    let milestones: [RaffleMilestone]
    let history: [RaffleHistoryItem]
    /// Launch-modal benefit cards; empty once the raffle itself carries content.
    let benefitCards: [RaffleBenefitCard]
    /// Client-side FAQ; empty on the results / ended screens.
    let faq: [RaffleFAQItem]
    let primaryButton: RaffleActionButton
    let showsTicketsCard: Bool
    let showsConfetti: Bool

    init(
        statusBadge: RaffleStatusBadge?,
        hero: RaffleHero,
        tickets: RaffleTicketsInfo,
        prizesTitle: String,
        prizes: [RafflePrize],
        earnTasks: [RaffleEarnTask],
        milestones: [RaffleMilestone],
        history: [RaffleHistoryItem],
        benefitCards: [RaffleBenefitCard] = [],
        faq: [RaffleFAQItem] = [],
        primaryButton: RaffleActionButton,
        showsTicketsCard: Bool,
        showsConfetti: Bool
    ) {
        self.statusBadge = statusBadge
        self.hero = hero
        self.tickets = tickets
        self.prizesTitle = prizesTitle
        self.prizes = prizes
        self.earnTasks = earnTasks
        self.milestones = milestones
        self.history = history
        self.benefitCards = benefitCards
        self.faq = faq
        self.primaryButton = primaryButton
        self.showsTicketsCard = showsTicketsCard
        self.showsConfetti = showsConfetti
    }
}
