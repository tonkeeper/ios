import SwiftUI
import TKLocalize
import TKUIKit

public struct StakingUpcomingRewardSectionState: Equatable {
    public let title: String
    public let amount: String
    public let subtitle: String

    public init(title: String, amount: String, subtitle: String) {
        self.title = title
        self.amount = amount
        self.subtitle = subtitle
    }
}

public struct StakingUpcomingRewardSectionView: View {
    private let state: StakingUpcomingRewardSectionState

    public init(state: StakingUpcomingRewardSectionState) {
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.StakingBalanceDetails.upcomingReward), titleTextStyle: .h3)

            Cell {
                CellCenter(
                    primaryRow: {
                        CellCenterPrimaryRow(
                            config: .content(
                                .init(
                                    title: state.title,
                                    value: .init(title: state.amount, color: .accentGreen)
                                )
                            )
                        )
                    },
                    secondaryRow: {
                        CellCenterSecondaryRow(config: .content(.init(value: .init(title: state.subtitle))))
                    }
                )
            }
            .asCellsGroup(config: StakingRewardsHistoryLayout.cellsGroup)
        }
        .padding(.horizontal, StakingRewardsHistoryLayout.horizontalPadding)
        .padding(.bottom, StakingRewardsHistoryLayout.horizontalPadding)
    }
}
