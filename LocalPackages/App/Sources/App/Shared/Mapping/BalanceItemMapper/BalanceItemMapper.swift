import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore
import BigInt

struct BalanceItemMapper {
  private let imageLoader = ImageLoader()
  
  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  
  init(amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter) {
    self.decimalAmountFormatter = decimalAmountFormatter
    self.amountFormatter = amountFormatter
  }
  
  func mapTonItem(_ item: ProcessedBalanceTonItem,
                  isSecure: Bool) -> TKUIListItemView.Configuration {
    let subtitle = createPriceSubtitle(
      price: item.price,
      currency: item.currency,
      diff: item.diff,
      verification: .whitelist
    )
    
    return TKUIListItemView.Configuration(
      iconConfiguration: .tonConfiguration(imageLoader: imageLoader),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: .tonConfiguration(subtitle: subtitle),
        rightItemConfiguration: createRightItemConfiguration(
          amount: BigUInt(item.amount),
          amountFractionDigits: TonInfo.fractionDigits,
          convertedAmount: item.converted,
          currency: item.currency,
          isSecure: isSecure
        )
      ),
      accessoryConfiguration: .none
    )
  }
  
  func mapJettonItem(_ item: ProcessedBalanceJettonItem,
                     isSecure: Bool) -> TKUIListItemView.Configuration {
    let subtitle = createPriceSubtitle(
      price: item.price,
      currency: item.currency,
      diff: item.diff,
      verification: item.jetton.jettonInfo.verification
    )
    
    return TKUIListItemView.Configuration(
      iconConfiguration: .configuration(jettonInfo: item.jetton.jettonInfo, imageLoader: imageLoader),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: .configuration(jettonInfo: item.jetton.jettonInfo, subtitle: subtitle),
        rightItemConfiguration: createRightItemConfiguration(
          amount: item.amount,
          amountFractionDigits: item.fractionalDigits,
          convertedAmount: item.converted,
          currency: item.currency,
          isSecure: isSecure
        )
      ),
      accessoryConfiguration: .none
    )
  }
  
  func mapStakingItem(_ item: ProcessedBalanceStakingItem,
                      isSecure: Bool) -> TKUIListItemView.Configuration {
    return TKUIListItemView.Configuration(
      iconConfiguration: .configuration(poolInfo: item.poolInfo, imageLoader: imageLoader),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: .configuration(title: TKLocales.BalanceList.StakingItem.title,
                                              poolInfo: item.poolInfo),
        rightItemConfiguration: createRightItemConfiguration(
          amount: BigUInt(item.info.amount),
          amountFractionDigits: TonInfo.fractionDigits,
          convertedAmount: item.amountConverted,
          currency: item.currency,
          isSecure: isSecure
        )
      ),
      accessoryConfiguration: .none
    )
  }
  
  private func createRightItemConfiguration(amount: BigUInt,
                                            amountFractionDigits: Int,
                                            convertedAmount: Decimal,
                                            currency: Currency,
                                            isSecure: Bool) -> TKUIListItemContentRightItem.Configuration {
    let formatAmount = {
      amountFormatter.formatAmount(
        amount,
        fractionDigits: amountFractionDigits,
        maximumFractionDigits: 2
      )
    }
    
    let formatConvertedAmount = {
      decimalAmountFormatter.format(
        amount: convertedAmount,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    
    let value = (isSecure ? String.secureModeValue : formatAmount()).withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let valueSubtitle = (isSecure ? String.secureModeValue : formatConvertedAmount()).withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    return TKUIListItemContentRightItem.Configuration(
      value: value,
      subtitle: valueSubtitle,
      description: nil
    )
  }
  
  private func createPriceSubtitle(price: Decimal?,
                                   currency: Currency,
                                   diff: String?,
                                   verification: JettonInfo.Verification) -> NSAttributedString {
    let result = NSMutableAttributedString()
    switch verification {
    case .none, .blacklist:
      result.append(
        TKLocales.Token.unverified.withTextStyle(
          .body2,
          color: .Accent.orange,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        )
      )
    case .whitelist:
      if let price {
        result.append(
          decimalAmountFormatter.format(
            amount: price,
            currency: currency
          ).withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          )
        )
        result.append(" ".withTextStyle(.body2, color: .Text.secondary))
      }
      
      if let diff {
        result.append({
          let color: UIColor
          if diff.hasPrefix("-") || diff.hasPrefix("−") {
            color = .Accent.red
          } else if diff.hasPrefix("+") {
            color = .Accent.green
          } else {
            color = .Text.tertiary
          }
          return diff.withTextStyle(.body2, color: color, alignment: .left)
        }())
      }
    }
    return result
  }
}
