import UIKit
import TKUIKit
import KeeperCore
import TKCore

extension TKUIListItemIconView.Configuration {
  static func tonConfiguration(imageLoader: ImageLoader) -> TKUIListItemIconView.Configuration {
    
    let iconConfigurationImage = TKUIListItemImageIconView.Configuration.Image.image(
      .TKCore.Icons.Size44.tonLogo
    )
    
    return  TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        TKUIListItemImageIconView.Configuration(
          image: iconConfigurationImage,
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: CGSize(width: 44, height: 44),
          cornerRadius: 22
        )
      ),
      alignment: .center
    )
  }
}
