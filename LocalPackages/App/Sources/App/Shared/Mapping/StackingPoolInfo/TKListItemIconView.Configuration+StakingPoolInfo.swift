import UIKit
import TKUIKit
import TKCore
import KeeperCore

extension TKListItemIconViewV2.Configuration {
  static func configuration(poolInfo: StackingPoolInfo?) -> TKListItemIconViewV2.Configuration {
    return TKListItemIconViewV2.Configuration(
      content: .image(TKImageView.Model(image: .image(.TKCore.Icons.Size44.tonLogo))),
      alignment: .center,
      cornerRadius: 22,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      badge: Badge(
        configuration: TKListItemBadgeView.Configuration.imageView(
          TKImageView.Model(
            image: .image(poolInfo?.implementation.icon),
            tintColor: .clear,
            size: .size(CGSize(width: 18, height: 18)),
            corners: .circle,
            padding: .zero
          )
        ),
        position: .bottomRight
      )
    )
  }
}
