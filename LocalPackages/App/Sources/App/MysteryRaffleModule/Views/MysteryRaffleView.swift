import Combine
import Kingfisher
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct MysteryRaffleView: View {
    @Environment(\.tkPalette) private var palette

    @ObservedObject var viewModel: MysteryRaffleViewModel

    @State private var scrollViewportFrame: CGRect = .zero
    @State private var contentHeight: CGFloat = 0

    private var contentFitsViewport: Bool {
        contentHeight > 0 && contentHeight <= scrollViewportFrame.height
    }

    var body: some View {
        Group {
            if let content = viewModel.content {
                loadedBody(content)
            } else {
                loadingBody
            }
        }
        .background(.backgroundPage)
    }

    private var loadingBody: some View {
        ZStack(alignment: .top) {
            RaffleLoaderRepresentable()
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            header
        }
    }

    private func loadedBody(_ content: MysteryRaffleContent) -> some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    contentSections(content, proxy: proxy)
                        .padding(.bottom, Layout.scrollBottomPadding)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { contentHeight = geo.size.height }
                                    .onChange(of: geo.size.height) { contentHeight = $0 }
                            }
                        )
                }
                .tkImmediateButtonPresses()
                .scrollDisabledIfFits(contentFitsViewport)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { scrollViewportFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { scrollViewportFrame = $0 }
                    }
                )
            }

            if content.showsConfetti {
                RaffleConfettiView()
            }

            // Floating overlay so the hero image bleeds to the top of the sheet;
            // the close button stays pinned top-right over the artwork.
            header

            actionBar(content.primaryButton)
        }
    }

    private func contentSections(_ content: MysteryRaffleContent, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            RaffleHeroView(hero: content.hero, statusBadge: content.statusBadge)

            if !content.benefitCards.isEmpty {
                RaffleBenefitCardsList(cards: content.benefitCards)
            }

            if content.showsTicketsCard {
                RaffleTicketsCard(
                    tickets: content.tickets,
                    onGetMore: {
                        viewModel.didTapGetMore()
                        scrollToEarnTickets(using: proxy)
                    }
                )
            }

            raffleSections(content)

            if !content.history.isEmpty {
                historySections(content.history)
            }

            if !content.faq.isEmpty {
                RaffleSectionTitle(title: TKLocales.MysteryRaffle.Faq.title)
                RaffleFAQList(items: content.faq)
            }
        }
    }

    @ViewBuilder
    private func raffleSections(_ content: MysteryRaffleContent) -> some View {
        if !content.prizes.isEmpty {
            RaffleSectionTitle(title: content.prizesTitle)
            RafflePrizesRow(prizes: content.prizes)
        }
        if !content.earnTasks.isEmpty {
            RaffleSectionTitle(title: TKLocales.MysteryRaffle.Section.earnTickets)
                .id(ScrollAnchor.earnTickets)
            RaffleEarnList(tasks: content.earnTasks, onTap: viewModel.didTapEarnTask)
        }
        if !content.milestones.isEmpty {
            RaffleSectionTitle(title: TKLocales.MysteryRaffle.Section.milestones)
            RaffleMilestonesList(milestones: content.milestones, onTap: { viewModel.didTapMilestone(id: $0) })
        }
    }

    @ViewBuilder
    private func historySections(_ history: [RaffleHistoryItem]) -> some View {
        RaffleSectionTitle(title: TKLocales.MysteryRaffle.Section.history)
            .id(ScrollAnchor.history)
        RaffleHistoryList(items: history)
    }
}

// MARK: - Header / background / action bar

private extension MysteryRaffleView {
    var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            RaffleCloseButton(action: viewModel.didTapClose)
        }
        .padding(.horizontal, 8)
        .frame(height: Layout.headerHeight)
    }

    func actionBar(_ button: RaffleActionButton) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ButtonView(
                config: ButtonView.Config(
                    title: button.title,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: viewModel.didTapPrimaryButton
                )
            )
            .padding(.horizontal, Layout.contentInset)
            .padding(.top, Layout.contentInset)
            .padding(.bottom, Layout.contentInsetBottom)
            .background(
                LinearGradient(
                    colors: [
                        palette.background.page.opacity(0),
                        palette.background.page,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    func scrollToEarnTickets(using proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(ScrollAnchor.earnTickets, anchor: .top)
        }
    }

    enum ScrollAnchor: Hashable {
        case history
        case earnTickets
    }

    enum Layout {
        static let headerHeight: CGFloat = 56
        static let contentInset: CGFloat = 16
        static let contentInsetBottom: CGFloat = 4
        static let scrollBottomPadding: CGFloat = 104
    }
}

/// `.scrollDisabled` needs iOS 16; App's min target is 15, so below that the sheet
/// keeps its default (scrollable) behavior even when content would otherwise fit.
private struct ScrollDisabledIfFits: ViewModifier {
    let fits: Bool

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDisabled(fits)
        } else {
            content
        }
    }
}

private extension View {
    func scrollDisabledIfFits(_ fits: Bool) -> some View {
        modifier(ScrollDisabledIfFits(fits: fits))
    }
}

// MARK: - Hero

/// The full-bleed hero illustration (`hero.image`); the bundled glyph is the placeholder
/// while it loads and the fallback when the URL is absent.
struct RaffleHeroArt: View {
    let imageURL: URL?
    let icon: RaffleSymbol

    var body: some View {
        if let imageURL {
            KFImage(source: RaffleKingfisherSource.source(imageURL))
                .resizable()
                .placeholder { glyph.frame(height: Self.placeholderHeight) }
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else {
            glyph
        }
    }

    private static let placeholderHeight: CGFloat = 276

    private var glyph: some View {
        RaffleImageView(source: .symbol(icon), size: 84, tint: .textAccent)
            .frame(maxWidth: .infinity)
    }
}

private struct RaffleHeroView: View {
    let hero: RaffleHero
    let statusBadge: RaffleStatusBadge?

    var body: some View {
        VStack(spacing: 0) {
            RaffleHeroArt(imageURL: hero.imageURL, icon: hero.icon)
                .padding(.bottom, 16)

            RaffleHeroTextContent(hero: hero, statusBadge: statusBadge)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
        }
    }
}

private struct RaffleHeroTextContent: View {
    let hero: RaffleHero
    let statusBadge: RaffleStatusBadge?

    var body: some View {
        VStack(spacing: 4) {
            if let statusBadge {
                RaffleStatusPill(badge: statusBadge)
                    .padding(.bottom, 8)
            }

            Text(hero.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -1)

            Text(hero.subtitle)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -4)

            if let countdown = hero.countdown {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    RaffleInfoLine(
                        icon: .TKUIKit.Icons.Size28.clock,
                        text: raffleCountdownText(to: countdown.target, now: RaffleClock.now(context.date), prefix: countdown.prefix),
                        tint: .textAccent
                    )
                }
                .padding(.vertical, 1)
            }

            if let moreOnDateText = hero.moreOnDateText {
                RaffleInfoLine(icon: .TKUIKit.Icons.Size28.clock, text: moreOnDateText, tint: .textAccent)
                    .padding(.vertical, 1)
            }
        }
    }
}

private struct RaffleInfoLine: View {
    let icon: UIImage
    let text: String
    let tint: TKColor

    var body: some View {
        HStack(spacing: 6) {
            TemplateIcon(image: icon, tint: tint, size: 18)
            Text(text)
                .textStyle(.body2.monospacedDigits())
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Tickets card

private struct RaffleTicketsCard: View {
    let tickets: RaffleTicketsInfo
    let onGetMore: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RaffleAccentBadge(symbol: .ticket, accent: .blue)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: -3) {
                Text(tickets.count)
                    .textStyle(.h3)
                    .foregroundStyle(.textPrimary)
                Text(tickets.caption)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Spacer(minLength: 0)

            if let getMoreTitle = tickets.getMoreTitle {
                ButtonView(
                    config: ButtonView.Config(
                        title: getMoreTitle,
                        size: .small,
                        layoutMode: .intrinsic,
                        appearance: .primary,
                        action: onGetMore
                    )
                )
                .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .raffleCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Prizes

private struct RafflePrizesRow: View {
    let prizes: [RafflePrize]

    private final class ScrollTracker {
        var currentIndex = 0
        var lastUserScroll = Date.distantPast
        var lastStep = Date.distantPast
        var programmaticDeadline = Date.distantPast
        var didCenter = false
    }

    @State private var tracker = ScrollTracker()
    @State private var viewportWidth: CGFloat = 0
    @State private var heartbeat = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private static let scrollSpace = "rafflePrizesScroll"

    enum Layout {
        static let cardWidth: CGFloat = 176
        static let cardHeight: CGFloat = 128
        static let spacing: CGFloat = 6
        static let horizontalInset: CGFloat = 16
        static let step: CGFloat = cardWidth + spacing
        static let stepInterval: TimeInterval = 2
        static let scrollDuration: TimeInterval = 0.4
    }

    private var copies: Int {
        guard !prizes.isEmpty else { return 0 }
        return max(200, Int((10000.0 / Double(prizes.count)).rounded(.up)))
    }

    private var totalItems: Int {
        prizes.count * copies
    }

    private var startIndex: Int {
        prizes.count * (copies / 2)
    }

    private var wrapHigh: Int {
        totalItems - prizes.count * 2
    }

    private var wrapLow: Int {
        prizes.count * 2
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0 ..< totalItems, id: \.self) { index in
                        RafflePrizeCard(prize: prizes[index % prizes.count])
                            .padding(.trailing, Layout.spacing)
                            .id(index)
                    }
                }
                .padding(.horizontal, Layout.horizontalInset)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named(Self.scrollSpace)).minX) { minX in
                                guard Date() >= tracker.programmaticDeadline else { return }
                                tracker.lastUserScroll = Date()
                                tracker.currentIndex = Int((-minX / Layout.step).rounded())
                            }
                    }
                )
            }
            .tkImmediateButtonPresses()
            .coordinateSpace(name: Self.scrollSpace)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { centerIfNeeded(width: geo.size.width, proxy: proxy) }
                        .onChange(of: geo.size.width) { centerIfNeeded(width: $0, proxy: proxy) }
                }
            )
            .padding(.bottom, 16)
            .onReceive(heartbeat) { _ in
                advanceIfDue(using: proxy)
            }
        }
    }

    private func centerIfNeeded(width: CGFloat, proxy: ScrollViewProxy) {
        viewportWidth = width
        guard !tracker.didCenter, width > Layout.step, !prizes.isEmpty else { return }
        tracker.didCenter = true
        tracker.currentIndex = startIndex
        tracker.lastStep = Date()
        tracker.programmaticDeadline = Date().addingTimeInterval(0.2)
        proxy.scrollTo(startIndex, anchor: leadingAnchor)
    }

    private func advanceIfDue(using proxy: ScrollViewProxy) {
        let now = Date()
        guard tracker.didCenter, !prizes.isEmpty, viewportWidth > Layout.step else { return }
        guard now >= tracker.programmaticDeadline else { return }
        guard now.timeIntervalSince(tracker.lastUserScroll) >= Layout.stepInterval else { return }

        if tracker.currentIndex >= wrapHigh || tracker.currentIndex <= wrapLow {
            tracker.currentIndex = startIndex + tracker.currentIndex % prizes.count
            tracker.programmaticDeadline = now.addingTimeInterval(0.1)
            proxy.scrollTo(tracker.currentIndex, anchor: leadingAnchor)
            return
        }

        guard now.timeIntervalSince(tracker.lastStep) >= Layout.stepInterval else { return }
        tracker.lastStep = now
        tracker.currentIndex += 1
        tracker.programmaticDeadline = now.addingTimeInterval(Layout.scrollDuration + 0.15)
        withAnimation(.easeInOut(duration: Layout.scrollDuration)) {
            proxy.scrollTo(tracker.currentIndex, anchor: leadingAnchor)
        }
    }

    private var leadingAnchor: UnitPoint {
        UnitPoint(x: Layout.horizontalInset / max(viewportWidth - Layout.step, 1), y: 0.5)
    }
}

private struct RafflePrizeCard: View {
    let prize: RafflePrize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RaffleImageView(source: prize.image, size: 44)
                .padding(.bottom, 8)

            Text(prize.title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .frame(height: 24)

            Text(prize.subtitle)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .frame(height: 20)
        }
        .padding(16)
        .frame(width: RafflePrizesRow.Layout.cardWidth, height: RafflePrizesRow.Layout.cardHeight, alignment: .topLeading)
        .raffleCard()
    }
}

// MARK: - Migration benefit cards

/// Week-1 migration modal ("Multichain is here"): stacked benefit cards under the hero.
private struct RaffleBenefitCardsList: View {
    let cards: [RaffleBenefitCard]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards) { card in
                RaffleBenefitCardView(card: card)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

/// A benefit card: text block (accent eyebrow + title + subtitle) on the leading edge,
/// with a full-height illustration bleeding on the trailing 134pt column.
private struct RaffleBenefitCardView: View {
    let card: RaffleBenefitCard

    /// Matches the Figma "Perps" column (card width − text column).
    private static let illustrationWidth: CGFloat = 134

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                if !card.label.isEmpty {
                    HStack(spacing: 0) {
                        TemplateIcon(image: card.icon.image, tint: card.accent.color, size: 16)
                            .padding(.leading, 2)
                            .padding(.trailing, 4)
                        Text(card.label.uppercased())
                            .textStyle(.body4Caps)
                            .foregroundStyle(card.accent.color)
                    }
                }

                Text(card.title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -2)

                Text(card.subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textPrimary.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -4)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.top, 16)
            .padding(.bottom, 15)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Reserve the illustration column; the art is drawn as a trailing overlay so
            // the card height is driven purely by the text block.
            Color.clear.frame(width: Self.illustrationWidth)
        }
        .background(.backgroundContent)
        .overlay(alignment: .trailing) {
            if let imageURL = card.imageURL {
                KFImage(source: RaffleKingfisherSource.source(imageURL))
                    .resizable()
                    .placeholder { Color.clear }
                    .scaledToFill()
                    .frame(width: Self.illustrationWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Earn tasks / milestones

private struct RaffleEarnList: View {
    let tasks: [RaffleEarnTask]
    let onTap: (RaffleEarnTask) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                row(for: task)
                if index < tasks.count - 1 {
                    RaffleDivider()
                }
            }
        }
        .raffleCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    /// Only `.chevron` (a task carrying a deeplink) is actionable — see
    /// `MysteryRaffleContent+Mapping.accessory(for:)`. Completed (`.done`) and
    /// plain informational (`.none`) rows render the same but aren't tappable.
    @ViewBuilder
    private func row(for task: RaffleEarnTask) -> some View {
        let row = RaffleAccentRow(
            icon: task.icon,
            accent: task.accent,
            title: task.title,
            subtitle: task.subtitle,
            accessory: task.accessory
        )
        if task.accessory == .chevron {
            Button {
                onTap(task)
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }
}

/// Milestone bonuses rendered as a vertical timeline: a connector line threads the
/// leading badges, achieved badges are accent-tinted, the rest neutral grey.
private struct RaffleMilestonesList: View {
    let milestones: [RaffleMilestone]
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                RaffleMilestoneRow(
                    milestone: milestone,
                    isFirst: index == 0,
                    isLast: index == milestones.count - 1,
                    onTap: { onTap(milestone.id) }
                )
                if index < milestones.count - 1 {
                    RaffleDivider(leading: RaffleMilestoneRow.titleLeadingInset)
                        .background(alignment: .leading) {
                            RaffleMilestoneRow.ConnectorDividerPatch()
                        }
                }
            }
        }
        .raffleCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

private struct RaffleMilestoneRow: View {
    @Environment(\.tkPalette) private var palette

    let milestone: RaffleMilestone
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

    private static let badgeSize: CGFloat = 44
    private static let leadingInset: CGFloat = 16
    private static let connectorBadgeGap: CGFloat = 4
    private static let connectorWidth: CGFloat = 2
    /// Where the title text starts: badge leading inset + badge width + text padding.
    static let titleLeadingInset: CGFloat = leadingInset + badgeSize + 16

    /// Only the current milestone carries a chevron — that row alone is tappable.
    private var isActionable: Bool {
        if case .chevron = milestone.accessory {
            return true
        }
        return false
    }

    /// Achieved milestones show a trailing checkmark unless they're the actionable
    /// (chevron) row — so the "joined" state marks every reached tier as done.
    private var displayedAccessory: RaffleRowAccessory {
        if case .none = milestone.accessory, milestone.isAchieved {
            return .done
        }
        return milestone.accessory
    }

    var body: some View {
        if isActionable {
            Button(action: onTap) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 0) {
            ZStack {
                connector
                RaffleAccentBadge(
                    symbol: milestone.icon,
                    accent: milestone.accent,
                    isAccented: milestone.isAchieved || isActionable
                )
            }
            .frame(width: Self.badgeSize)
            .padding(.leading, Self.leadingInset)

            VStack(alignment: .leading, spacing: -4) {
                Text(milestone.title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(milestone.subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 15)

            Spacer(minLength: 0)

            // `.none` self-collapses to EmptyView; achieved rows show a checkmark, the
            // current row a chevron.
            RaffleRowAccessoryView(accessory: displayedAccessory)
                .padding(.trailing, 16)
        }
    }

    private var connector: some View {
        VStack(spacing: 0) {
            connectorSegment.opacity(isFirst ? 0 : 1)
            Color.clear.frame(height: Self.badgeSize + 2 * Self.connectorBadgeGap)
            connectorSegment.opacity(isLast ? 0 : 1)
        }
    }

    private var connectorSegment: some View {
        palette.separator.common
            .frame(width: Self.connectorWidth)
            .frame(maxHeight: .infinity)
    }

    struct ConnectorDividerPatch: View {
        @Environment(\.tkPalette) private var palette

        var body: some View {
            palette.separator.common
                .frame(width: RaffleMilestoneRow.connectorWidth)
                .padding(.leading, RaffleMilestoneRow.leadingInset + (RaffleMilestoneRow.badgeSize - RaffleMilestoneRow.connectorWidth) / 2)
        }
    }
}

private struct RaffleAccentRow: View {
    let icon: RaffleSymbol
    let accent: RaffleAccent
    let title: String
    let subtitle: String
    let accessory: RaffleRowAccessory

    var body: some View {
        HStack(spacing: 0) {
            RaffleAccentBadge(symbol: icon, accent: accent)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: -4) {
                Text(title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 15)

            Spacer(minLength: 0)

            RaffleRowAccessoryView(accessory: accessory)
                .padding(.trailing, 16)
        }
    }
}

private struct RaffleRowAccessoryView: View {
    let accessory: RaffleRowAccessory

    var body: some View {
        switch accessory {
        case .done:
            TemplateIcon(image: .TKUIKit.Icons.Size28.donemarkOutline, tint: .textAccent, size: 28)
        case .chevron:
            TemplateIcon(image: .TKUIKit.Icons.Size16.chevronRight, tint: .iconTertiary, size: 16)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - History

private struct RaffleHistoryList: View {
    let items: [RaffleHistoryItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                RaffleHistoryRow(item: item)
                if index < items.count - 1 {
                    RaffleDivider()
                }
            }
        }
        .raffleCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

private struct RaffleHistoryRow: View {
    let item: RaffleHistoryItem

    var body: some View {
        HStack(spacing: 0) {
            RaffleHistoryBadge(symbol: item.icon)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: -6) {
                HStack(spacing: 16) {
                    Text(item.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                    Spacer(minLength: 0)
                    Text(item.amountText)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                }
                Text(item.dateText)
                    .textStyle(.body2.monospacedDigits())
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 15)
        }
    }
}

// MARK: - FAQ

private struct RaffleFAQList: View {
    let items: [RaffleFAQItem]

    @State private var expandedID: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                RaffleFAQRow(
                    item: item,
                    isExpanded: expandedID == item.id,
                    onToggle: { toggle(item.id) }
                )
                if index < items.count - 1 {
                    RaffleDivider()
                }
            }
        }
        .raffleCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func toggle(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedID = expandedID == id ? nil : id
        }
    }
}

private struct RaffleFAQRow: View {
    let item: RaffleFAQItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(item.question)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    TemplateIcon(image: .TKUIKit.Icons.Size16.chevronDown, tint: .iconTertiary, size: 16)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                if isExpanded {
                    Text(item.answer)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared building blocks

private struct RaffleSectionTitle: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct RaffleLoaderRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> TKLoaderView {
        let view = TKLoaderView(size: .medium, style: .primary)
        view.isLoading = true
        return view
    }

    func updateUIView(_ uiView: TKLoaderView, context: Context) {}
}

private struct RaffleDivider: View {
    @Environment(\.tkPalette) private var palette

    var leading: CGFloat = 16

    var body: some View {
        palette.separator.common
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}

private extension View {
    /// Rounded 16 card on the content background, matching the design's list groups.
    func raffleCard() -> some View {
        asCellsGroup(config: .init(horizontalPadding: 0))
    }
}

// MARK: - Previews
