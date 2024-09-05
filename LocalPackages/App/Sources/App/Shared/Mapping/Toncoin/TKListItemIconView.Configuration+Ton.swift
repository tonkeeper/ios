import UIKit
import TKUIKit
import TKCore

extension TKListItemIconViewV2.Configuration {
  static func tonConfiguration() -> TKListItemIconViewV2.Configuration {
    return TKListItemIconViewV2.Configuration(
      content: .image(TKImageView.Model(image: .image(.TKCore.Icons.Size44.tonLogo))),
      alignment: .center,
      cornerRadius: 22,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      badge: nil
    )
  }
}
