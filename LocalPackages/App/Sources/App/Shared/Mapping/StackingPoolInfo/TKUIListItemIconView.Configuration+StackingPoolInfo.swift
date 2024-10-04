import UIKit
import TKUIKit
import KeeperCore
import TKCore

extension TKUIListItemIconView.Configuration {
  static func configuration(poolInfo: StackingPoolInfo?,
                            imageLoader: ImageLoader) -> TKUIListItemIconView.Configuration {
    
    let iconConfigurationImage = TKUIListItemImageIconView.Configuration.Image.image(
      .TKCore.Icons.Size44.tonLogo
    )
    
    let badgeImage = TKUIListItemImageIconView.Configuration.Image.image(poolInfo?.implementation.icon)
    let badgeIconConfiguration = TKUIListItemImageIconView.Configuration(
      image: badgeImage,
      tintColor: .Icon.primary,
      backgroundColor: .Background.contentTint,
      size: .badgeIconSize,
      cornerRadius: 10,
      borderWidth: 2,
      borderColor: .Background.content,
      contentMode: .scaleAspectFill
    )
    
    return  TKUIListItemIconView.Configuration(
      iconConfiguration: .imageWithBadge(
        TKUIListItemImageIconView.Configuration(
          image: iconConfigurationImage,
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: .iconSize,
          cornerRadius: 22
        ),
        badgeIconConfiguration
      ),
      alignment: .center
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
  static let badgeIconSize = CGSize(width: 18, height: 18)
}
