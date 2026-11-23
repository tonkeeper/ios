import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Rewards history section", traits: .fixedLayout(width: 390, height: 300)) {
    StakingRewardsHistorySectionView(state: .preview, onOpenHistory: {})
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Upcoming reward", traits: .fixedLayout(width: 390, height: 260)) {
    VStack(spacing: 0) {
        StakingUpcomingRewardSectionView(
            state: StakingUpcomingRewardSectionState(
                title: "Current round",
                amount: "≈ 1.25 GRAM",
                subtitle: "Ends in ~6 hours"
            )
        )
        StakingUpcomingRewardSectionView(
            state: StakingUpcomingRewardSectionState(
                title: "First reward",
                amount: "≈ 1.25 GRAM",
                subtitle: "Ends in ~6 hours"
            )
        )
    }
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Rewards history / All time", traits: .fixedLayout(width: 390, height: 844)) {
    StakingRewardsHistoryView(
        state: .previewAllTime,
        onBack: {},
        onSelectPeriod: { _ in },
        onAppearRow: { _ in },
        onRefresh: {},
        onRetry: {}
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Rewards history / Loading", traits: .fixedLayout(width: 390, height: 844)) {
    StakingRewardsHistoryView(
        state: .previewLoading,
        onBack: {},
        onSelectPeriod: { _ in },
        onAppearRow: { _ in },
        onRefresh: {},
        onRetry: {}
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Rewards history / Failed", traits: .fixedLayout(width: 390, height: 844)) {
    StakingRewardsHistoryView(
        state: .previewFailed,
        onBack: {},
        onSelectPeriod: { _ in },
        onAppearRow: { _ in },
        onRefresh: {},
        onRetry: {}
    )
    .tkPreviewTheme(.deepBlue)
}

private extension StakingRewardRowState {
    static let previewRows: [StakingRewardRowState] = [
        ("21 Oct, 06:00", "12.72%"), ("20 Oct, 12:00", "12.68%"), ("19 Oct, 18:00", "12.74%"),
        ("19 Oct, 00:00", "12.70%"), ("18 Oct, 06:00", "12.66%"), ("17 Oct, 12:00", "12.71%"),
        ("16 Oct, 18:00", "12.69%"), ("16 Oct, 00:00", "12.75%"),
    ].map { date, apy in
        StakingRewardRowState(id: date, amount: "+1.25 GRAM", apy: "APY \(apy)", date: date)
    }
}

private extension StakingRewardsHistorySectionState {
    static let preview = StakingRewardsHistorySectionState(
        total: "146.08 GRAM",
        rows: Array(StakingRewardRowState.previewRows.prefix(3))
    )
}

private extension StakingRewardsHistoryState {
    static let periods = ["All time", "1 month", "6 months", "1 year"]

    static let previewAllTime = StakingRewardsHistoryState(
        total: .init(amount: "146.08 GRAM", fiat: "$268.78"),
        periods: periods,
        selectedPeriodIndex: 0,
        content: .rows(StakingRewardRowState.previewRows, isLoadingMore: false, isLoadMoreFailed: false)
    )

    static let previewLoading = StakingRewardsHistoryState(
        total: nil,
        periods: periods,
        selectedPeriodIndex: 1,
        content: .loading
    )

    static let previewFailed = StakingRewardsHistoryState(
        total: nil,
        periods: periods,
        selectedPeriodIndex: 0,
        content: .failed
    )
}
