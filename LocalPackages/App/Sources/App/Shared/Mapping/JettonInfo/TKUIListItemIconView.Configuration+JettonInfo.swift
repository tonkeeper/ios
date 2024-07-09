import UIKit
import TKUIKit
import KeeperCore
import TKCore

extension TKUIListItemIconView.Configuration {
  static func configuration(jettonInfo: JettonInfo,
                            imageLoader: ImageLoader) -> TKUIListItemIconView.Configuration {
    
    let iconConfigurationImage = TKUIListItemImageIconView.Configuration.Image.asyncImage(
      jettonInfo.imageURL,
      TKCore.ImageDownloadTask(
        closure: {
          [imageLoader] imageView,
          size,
          cornerRadius in
          return imageLoader.loadImage(
            url: jettonInfo.imageURL,
            imageView: imageView,
            size: size,
            cornerRadius: cornerRadius
          )
        }
      )
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
