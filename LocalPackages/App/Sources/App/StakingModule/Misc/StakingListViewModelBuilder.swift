import UIKit
import TKUIKit
import KeeperCore
import BigInt
import TKLocalize

struct StakingListViewModelBuilder {
  private let decimalFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  init(decimalFormatter: DecimalAmountFormatter, amountFormatter: AmountFormatter) {
    self.decimalFormatter = decimalFormatter
    self.amountFormatter = amountFormatter
  }
  
  func build(stakingPoolInfo: StackingPoolInfo, isMaxAPY: Bool) -> StakingDetailsListView.Model {
    let percentFormatted = decimalFormatter.format(amount: stakingPoolInfo.apy, maximumFractionDigits: 2)
    let percentValue = "≈ \(percentFormatted)%"
    let minimumFormatted = amountFormatter.formatAmount(
      BigUInt(
        UInt64(stakingPoolInfo.minStake)
      ),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      symbol: TonInfo.symbol
    )
    
    var apyTag: TKUITagView.Configuration?
    if isMaxAPY {
      apyTag = TKUITagView.Configuration(
        text: .mostProfitableTag,
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.16)
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
        )
      ]
    )
  }
}

private extension String {
  static let mostProfitableTag = TKLocales.maxApy
  static let apy = TKLocales.apy
  static let minimalDeposit = TKLocales.StakingList.minimalDeposit
}
