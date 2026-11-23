import SwiftUI
import TKLocalize
import TKUIKit

public struct StakingRewardsHistorySectionView: View {
    private let state: StakingRewardsHistorySectionState
    private let onOpenHistory: () -> Void

    public init(state: StakingRewardsHistorySectionState, onOpenHistory: @escaping () -> Void) {
        self.state = state
        self.onOpenHistory = onOpenHistory
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.StakingBalanceDetails.rewardsHistory,
                    accessory: ListTitleView.Accessory(
                        title: TKLocales.StakingBalanceDetails.rewardsHistoryTotal(state.total),
                        icon: .TKUIKit.Icons.Size16.chevronRight,
                        foregroundColor: .textSecondary,
                        action: onOpenHistory
                    )
                ),
                titleTextStyle: .h3
            )

            VStack(spacing: 0) {
                ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                    StakingRewardCell(row: row, showsDivider: index < state.rows.count - 1)
                }
            }
            .asCellsGroup(config: StakingRewardsHistoryLayout.cellsGroup)
        }
        .padding(.horizontal, StakingRewardsHistoryLayout.horizontalPadding)
        .padding(.bottom, StakingRewardsHistoryLayout.horizontalPadding)
    }
}

enum StakingRewardsHistoryLayout {
    static let horizontalPadding: CGFloat = 16
    static let cellsGroup = CellsGroupModifier.Config(
        horizontalPadding: 0,
        cornerRadius: 16,
        backgroundColor: .backgroundContent
    )
}
