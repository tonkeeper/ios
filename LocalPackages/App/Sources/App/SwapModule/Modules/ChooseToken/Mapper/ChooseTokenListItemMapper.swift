import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

struct ChooseTokenListItemMapper {

  let imageLoader = ImageLoader()

  func make() -> TKUIListItemCell.Configuration {
    
    let item = WalletBalanceItemsModel.Item(
      identifier: UUID().uuidString,
      token: .ton,
      image: .ton,
      title: "TON",
      price: "Toncoin",
      rateDiff: nil,
      amount: "100,000.01",
      convertedAmount: "$668,001.66",
      verification: .whitelist,
      hasPrice: true
    )

//    let id: String
//    switch item.token {
//    case .ton:
//      id = "ton"
//    case .jetton(let jettonItem):
//      id = jettonItem.jettonInfo.address.toRaw()
//    }
    let id = UUID().uuidString
    
    let title = item.title.withTextStyle(
      .label1,
      color: .white,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = NSMutableAttributedString()
    switch item.verification {
    case .none:
      subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    case .whitelist:
      if let price = item.price?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ) {
        subtitle.append(price)
        subtitle.append(" ".withTextStyle(.body2, color: .Text.secondary))
      }
    case .blacklist:
      subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    }
    
    let value = item.amount?.withTextStyle(
      .label1,
      color: .white,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let valueSubtitle = item.convertedAmount?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image
    switch item.image {
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
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: nil,
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
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: nil
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}
