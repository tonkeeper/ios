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
                  isSecure: Bool,
                  isPinned: Bool) -> TKListItemContentViewV2.Configuration {
    let caption = createPriceSubtitle(
      price: item.price,
      currency: item.currency,
      diff: item.diff,
      verification: .whitelist
    )
    
    return TKListItemContentViewV2.Configuration(
      iconViewConfiguration: .tonConfiguration(),
      textContentViewConfiguration: createTextContentViewConfiguration(
        title: TonInfo.symbol,
        isPinned: isPinned,
        caption: caption,
        amount: BigUInt(item.amount),
        amountFractionDigits: TonInfo.fractionDigits,
        convertedAmount: item.converted,
        currency: item.currency,
        isSecure: isSecure
      )
    )
  }
  
  func mapJettonItem(_ item: ProcessedBalanceJettonItem,
                     isSecure: Bool,
                     isPinned: Bool) -> TKListItemContentViewV2.Configuration {
    let caption = createPriceSubtitle(
      price: item.price,
      currency: item.currency,
      diff: item.diff,
      verification: .whitelist
    )
    
    return TKListItemContentViewV2.Configuration(
      iconViewConfiguration: .configuration(jettonInfo: item.jetton.jettonInfo),
      textContentViewConfiguration: createTextContentViewConfiguration(
        title: (item.jetton.jettonInfo.symbol ?? item.jetton.jettonInfo.name),
        isPinned: isPinned,
        caption: caption,
        amount: BigUInt(item.amount),
        amountFractionDigits: TonInfo.fractionDigits,
        convertedAmount: item.converted,
        currency: item.currency,
        isSecure: isSecure
      )
    )
  }
  
  func mapStakingItem(_ item: ProcessedBalanceStakingItem,
                      isSecure: Bool,
                      isPinned: Bool) -> TKListItemContentViewV2.Configuration {
    return TKListItemContentViewV2.Configuration(
      iconViewConfiguration: .configuration(poolInfo: item.poolInfo),
      textContentViewConfiguration: createTextContentViewConfiguration(
        title: TKLocales.BalanceList.StakingItem.title,
        isPinned: isPinned,
        caption: item.poolInfo?.name.withTextStyle(.body2, color: .Text.secondary),
        amount: BigUInt(item.info.amount),
        amountFractionDigits: TonInfo.fractionDigits,
        convertedAmount: item.amountConverted,
        currency: item.currency,
        isSecure: isSecure
      )
    )
  }
  
  private func createTextContentViewConfiguration(title: String,
                                                  isPinned: Bool,
                                                  caption: NSAttributedString?, 
                                                  amount: BigUInt,
                                                  amountFractionDigits: Int,
                                                  convertedAmount: Decimal,
                                                  currency: Currency,
                                                  isSecure: Bool) -> TKListItemTextContentViewV2.Configuration {
    var icon: TKListItemTitleView.Configuration.Icon?
    if isPinned {
      icon = TKListItemTitleView.Configuration.Icon(image: .TKUIKit.Icons.Size12.pin, tintColor: .Icon.tertiary)
    }
    let titleViewConfiguration = TKListItemTitleView.Configuration(title: title, icon: icon)
    
    var captionViewsConfigurations = [TKListItemTextView.Configuration]()
    if let caption {
      captionViewsConfigurations.append(TKListItemTextView.Configuration(text: caption))
    }
                                        
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
    let valueCaption = (isSecure ? String.secureModeValue : formatConvertedAmount()).withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    return TKListItemTextContentViewV2.Configuration(
      titleViewConfiguration: titleViewConfiguration,
      captionViewsConfigurations: captionViewsConfigurations,
      valueViewConfiguration: TKListItemTextView.Configuration(text: value),
      valueCaptionViewConfiguration: TKListItemTextView.Configuration(text: valueCaption)
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
