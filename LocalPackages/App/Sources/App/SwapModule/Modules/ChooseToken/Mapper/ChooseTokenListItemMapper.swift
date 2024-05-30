import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

struct ChooseTokenListItemMapper {

  let imageLoader = ImageLoader()

  func mapAvailabeToken(_ availableToken: AvailableTokenModelItem, selectionClosure: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let id: String
    let symbolString: String
    let tokenName: String
    let tokenImage: TokenImage
    var verification: JettonInfo.Verification = .whitelist
    let amount = availableToken.amount ?? "0"
    let convertedAmount = availableToken.convertedAmount ?? "0"
    switch availableToken.token {
    case .ton:
      id = "ton"
      symbolString = TonInfo.symbol
      tokenName = TonInfo.name
      tokenImage = .ton
    case .jetton(let jettonItem):
      let jettonInfo = jettonItem.jettonInfo
      id = jettonInfo.address.toRaw()
      symbolString = jettonInfo.symbol?.uppercased() ?? ""
      tokenName = jettonInfo.name.capitalized
      tokenImage = .url(jettonInfo.imageURL)
      verification = jettonInfo.verification
    }
    
    let title = symbolString.withTextStyle(
      .label1,
      color: .white,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = NSMutableAttributedString()
    switch verification {
    case .none, .blacklist:
      subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange))
    case .whitelist:
      let price = tokenName.withTextStyle(.body2, color: .Text.secondary)
      subtitle.append(price)
    }
    
    let value = amount.withTextStyle(.label1, color: amount == "0" ? .Text.secondary : .white, alignment: .right)
    let valueSubtitle = convertedAmount.withTextStyle(.body2, color: .Text.secondary, alignment: .right)
    
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image
    switch tokenImage {
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
          subtitle: amount == "0" ? nil : valueSubtitle ,
          description: nil
        )
      ),
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionClosure
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}
