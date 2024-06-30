import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct WalletBalanceListMapper {
  
  let imageLoader = ImageLoader()
  
  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let rateConverter: RateConverter
  
  init(amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter,
       rateConverter: RateConverter) {
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
    self.rateConverter = rateConverter
  }
  
  func mapItem(_ item: BalanceListModel.BalanceListItem) -> TKUIListItemCell.Configuration {
    let amount = amountFormatter.formatAmount(
      item.amount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    
    let converted = decimalAmountFormatter.format(
      amount: item.converted,
      maximumFractionDigits: 2,
      currency: item.currency
    )
    
    let price = decimalAmountFormatter.format(
      amount: item.price,
      currency: item.currency
    )
    
    let verification: JettonInfo.Verification = {
      switch item.type {
      case .ton:
        return .whitelist
      case .jetton(let jettonItem):
        return jettonItem.jettonInfo.verification
      }
    }()
    
    let image: TokenImage = {
      switch item.image {
      case .ton:
        return .ton
      case .url(let url):
        return .url(url)
      }
    }()
    
    let itemModel = ItemModel(
      title: item.title,
      tag: item.tag,
      image: image,
      price: price,
      rateDiff: item.diff,
      amount: amount,
      convertedAmount: converted,
      verification: verification
    )
    
    return mapItemModel(itemModel)
  }

  private func mapItemModel(_ itemModel: ItemModel) -> TKUIListItemCell.Configuration {
    let title = itemModel.title.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = NSMutableAttributedString()
    
    switch itemModel.verification {
    case .none:
      subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    case .whitelist:
      if let price = itemModel.price?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ) {
        subtitle.append(price)
        subtitle.append(" ".withTextStyle(.body2, color: .Text.secondary))
      }
      
      if let diff = itemModel.rateDiff {
        let color: UIColor
        if diff.hasPrefix("-") || diff.hasPrefix("−") {
          color = .Accent.red
        } else if diff.hasPrefix("+") {
          color = .Accent.green
        } else {
          color = .Text.tertiary
        }
        subtitle.append(diff.withTextStyle(.body2, color: color, alignment: .left))
      }
    case .blacklist:
      subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    }
    
    let value = itemModel.amount?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let valueSubtitle = itemModel.convertedAmount?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image
    switch itemModel.image {
    case .ton:
      iconConfigurationImage = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      iconConfigurationImage = .asyncImage(
        url,
        TKCore.ImageDownloadTask(
          closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            return imageLoader.loadImage(
              url: url,
              imageView: imageView,
              size: size,
              cornerRadius: cornerRadius
            )
          }
        )
      )
    }
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        TKUIListItemImageIconView.Configuration(
          image: iconConfigurationImage,
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: .iconSize,
          cornerRadius: CGSize.iconSize.height/2
        )
      ),
      alignment: .center
    )
    
    var tagViewModel: TKUITagView.Configuration?
    if let tag = itemModel.tag {
      tagViewModel = TKUITagView.Configuration(
        text: tag,
        textColor: .Text.secondary,
        backgroundColor: .Background.contentTint
      )
    }
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: tagViewModel,
          subtitle: subtitle,
          description: nil
        ),
        rightItemConfiguration: TKUIListItemContentRightItem.Configuration(
          value: value,
          subtitle: valueSubtitle,
          description: nil
        )
      ),
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: "",
      listItemConfiguration: listItemConfiguration,
      selectionClosure: nil
    )
  }
}

private struct ItemModel {
  public let title: String
  public let tag: String?
  public let image: TokenImage
  public let price: String?
  public let rateDiff: String?
  public let amount: String?
  public let convertedAmount: String?
  public let verification: JettonInfo.Verification
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}

