import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

struct StakingListViewModelBuilder {
    private let amountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    func build(stakingPoolInfo: StackingPoolInfo, isMaxAPY: Bool) -> StakingDetailsListView.Model {
        let percentFormatted = amountFormatter.format(
            decimal: stakingPoolInfo.apy,
            accessory: .none,
            style: .compact
        )
        let percentValue = "≈ \(percentFormatted)%"
        let minimumFormatted = amountFormatter.format(
            amount: BigUInt(
                UInt64(stakingPoolInfo.minStake)
            ),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .symbol(TonInfo.symbol),
            isNegative: false,
            style: .compact
        )

        var apyTag: TKTagView.Configuration?
        if isMaxAPY {
            apyTag = .accentTag(
                text: .mostProfitableTag,
                color: .Accent.green
            )
        }

        return StakingDetailsListView.Model(
            items: [
                StakingDetailsListView.ItemView.Model(
                    title: String.apy.withTextStyle(
                        .body2,
                        color: .Text.secondary,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    tag: apyTag,
                    value: percentValue.withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
                ),
                StakingDetailsListView.ItemView.Model(
                    title: String.minimalDeposit.withTextStyle(
                        .body2,
                        color: .Text.secondary,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    tag: nil,
                    value: minimumFormatted.withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
                ),
            ]
        )
    }
}

private extension String {
    static let mostProfitableTag = TKLocales.maxApy
    static let apy = TKLocales.apy
    static let minimalDeposit = TKLocales.StakingList.minimalDeposit
}
