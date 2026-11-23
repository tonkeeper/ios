import SwiftUI
import TKLocalize
import TKUIKit

struct StakingRewardCell: View {
    let row: StakingRewardRowState
    let showsDivider: Bool

    var body: some View {
        TransactionCell(
            config: .content(
                TransactionCellContent(
                    icon: TransactionCellContent.Icon(image: .TKUIKit.Icons.Size28.percentOutline),
                    title: TKLocales.StakingBalanceDetails.reward,
                    subtitle: .init(text: row.apy, style: .primary),
                    amount: .init(title: row.amount, style: .positive),
                    accessory: .init(text: row.date),
                    showsDivider: showsDivider
                )
            )
        )
    }
}

struct StakingRewardShimmerCell: View {
    var body: some View {
        TransactionCell(config: .shimmer)
    }
}
