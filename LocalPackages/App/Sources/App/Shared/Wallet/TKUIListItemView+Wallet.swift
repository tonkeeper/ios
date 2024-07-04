import TKUIKit
import UIKit
import KeeperCore

extension TKUIListItemView.Configuration {
  static func configuration(wallet: Wallet,
                            subtitle: String? = nil,
                            accessoryConfiguration: TKUIListItemAccessoryView.Configuration = .none) -> TKUIListItemView.Configuration {
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: wallet.label.withTextStyle(.label1, color: .Text.primary, alignment: .left),
        tagViewModel: wallet.listTagConfiguration(),
        subtitle: subtitle?.withTextStyle(.body2, color: .Text.secondary, alignment: .left),
        description: nil
      ),
      rightItemConfiguration: nil
    )
    
    let iconConfiguration: TKUIListItemIconView.Configuration.IconConfiguration
    switch wallet.icon {
    case .emoji(let emoji):
      iconConfiguration = .emoji(TKUIListItemEmojiIconView.Configuration(
        emoji: emoji,
        backgroundColor: wallet.tintColor.uiColor
      ))
    case .icon(let image):
      iconConfiguration = .image(TKUIListItemImageIconView.Configuration(
        image: .image(image.image),
        tintColor: .white,
        backgroundColor: wallet.tintColor.uiColor,
        size: CGSize(width: 44, height: 44),
        cornerRadius: 22,
        contentMode: .scaleAspectFit,
        imageSize: CGSize(width: 22, height: 22)
      ))
    }

    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: iconConfiguration,
        alignment: .center
      ),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: accessoryConfiguration
    )
    return listItemConfiguration
  }
}
