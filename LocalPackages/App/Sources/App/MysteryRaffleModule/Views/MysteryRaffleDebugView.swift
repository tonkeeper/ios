import KeeperCore
import SwiftUI
import TKUIKit
import UIKit

/// Design-review + QA scaffolding (dev-menu only). Gathers every Mystery Raffle surface on
/// one screen:
///  • the home banner and the list-cell entry point, in both states,
///  • one row per modal state (weeks / new|existing / results) — each opens the sheet,
///  • the contract's QA hooks: the `_debug_now` clock override and `pick-winners`,
///  • the live raffle's stories, so backend-driven pages can be reviewed on demand.
struct MysteryRaffleDebugView: View {
    @ObservedObject var viewModel: MysteryRaffleDebugViewModel

    let onSelectState: (MysteryRaffleContent) -> Void
    let onOpenLiveRaffle: (MultichainRaffle) -> Void
    let onSelectStory: (MultichainRaffleStory) -> Void
    let onResetShownStories: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                section("Banner") { banner }
                section("Entry point") { entryPoints }
                section("Live raffle") { liveRaffle }
                section("States") { states }
                section("QA · _debug_now") { debugNow }
                section("QA · pick-winners") { pickWinners }
                if !viewModel.stories.isEmpty {
                    section("Stories (live raffle)") { stories }
                }
                if let lastResult = viewModel.lastResult {
                    Text(lastResult)
                        .textStyle(.body3)
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(EdgeInsets(top: 15, leading: 16, bottom: 16, trailing: 16))
        }
        .background(TKColor.backgroundPage.ignoresSafeArea())
    }

    private var banner: some View {
        BannerItemView(
            item: BannerItem(
                title: "Mystery Raffle is live! Win a share of $100K prize pool",
                actionTitle: "Join Mystery Raffle",
                action: { onSelectState(.stubActive) }
            ),
            height: 90
        )
        .bannerItem()
    }

    private var entryPoints: some View {
        VStack(spacing: 12) {
            RaffleEntryPointView(title: "Join Mystery Raffle", ticketsText: nil) {
                onSelectState(.stubActive)
            }
            RaffleEntryPointView(title: "Mystery Raffle", ticketsText: "123 tickets") {
                onSelectState(.stubActive)
            }
        }
    }

    /// Opens the modal built from the backend raffle (not a stub), so the real payload —
    /// benefit cards, badges, CTA — can be reviewed together with the `_debug_now` shifts below.
    @ViewBuilder
    private var liveRaffle: some View {
        if let raffle = viewModel.raffle {
            card {
                Button { onOpenLiveRaffle(raffle) } label: {
                    row("Open modal", detail: "\(raffle.id) · \(raffle.status)")
                }
                .buttonStyle(.plain)
            }
        } else {
            Text("No raffle loaded for the active wallet")
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .padding(.top, -1)
        }
    }

    private var states: some View {
        card {
            ForEach(MysteryRaffleDevState.allCases, id: \.rawValue) { state in
                if state != MysteryRaffleDevState.allCases.first {
                    Divider().overlay(TKColor.separatorCommon)
                }
                Button { onSelectState(state.content) } label: { row(state.title) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var stories: some View {
        VStack(alignment: .leading, spacing: 12) {
            card {
                ForEach(viewModel.stories) { story in
                    if story.id != viewModel.stories.first?.id {
                        Divider().overlay(TKColor.separatorCommon)
                    }
                    Button { onSelectStory(story) } label: {
                        row(story.id, detail: "\(story.pages.count) pages")
                    }
                    .buttonStyle(.plain)
                }
            }
            // The auto-open story fires once per story per install; this brings it back.
            actionButton("Forget shown stories", action: onResetShownStories)
        }
    }

    private var debugNow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.debugNow.map(MysteryRaffleDebugViewModel.dateFormatter.string(from:)) ?? "Off — server clock")
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .padding(.bottom, -2)

            DatePicker(
                "Pretend now is",
                selection: Binding(
                    get: { viewModel.debugNow ?? Date() },
                    set: { viewModel.setDebugNow($0) }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(Font(TKTextStyle.label1.font))
            .foregroundStyle(.textPrimary)

            HStack(spacing: 8) {
                actionButton("−1 week") { viewModel.shiftDebugNow(byWeeks: -1) }
                actionButton("+1 week") { viewModel.shiftDebugNow(byWeeks: 1) }
                actionButton("Reset") { viewModel.setDebugNow(nil) }
            }
        }
        .padding(EdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TKColor.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var pickWinners: some View {
        if let raffle = viewModel.raffle {
            VStack(spacing: 0) {
                Button { viewModel.pickWinnersRandomly() } label: {
                    row("Run picker for all wallets")
                }
                .buttonStyle(.plain)

                ForEach(raffle.prizes) { prize in
                    Divider().overlay(TKColor.separatorCommon)
                    Button { viewModel.makeCurrentWalletWin(prize: prize) } label: {
                        row("This wallet wins", detail: prize.title)
                    }
                    .buttonStyle(.plain)
                }

                Divider().overlay(TKColor.separatorCommon)
                Button { viewModel.clearCurrentWalletWin() } label: {
                    row("Clear winner for this wallet")
                }
                .buttonStyle(.plain)
            }
            .disabled(viewModel.isRunning)
            .background(TKColor.backgroundContent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Text("No raffle loaded for the active wallet")
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .padding(.top, -1)
        }
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(TKColor.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ title: String, detail: String? = nil) -> some View {
        HStack {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.iconTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textStyle(.label2)
                .foregroundStyle(.textAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(TKColor.accentBlue.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.label2)
                .foregroundStyle(.textSecondary)
            content()
        }
    }
}
