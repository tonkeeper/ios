import UIKit
import TKUIKit
import TKCore

extension TKListItemIconView.Configuration {
  static func tonConfiguration() -> TKListItemIconView.Configuration {
    return TKListItemIconView.Configuration(
      content: .image(TKImageView.Model(image: .image(.TKCore.Icons.Size44.tonLogo))),
      alignment: .center,
      cornerRadius: 22,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      badge: nil
    )
  }
}
