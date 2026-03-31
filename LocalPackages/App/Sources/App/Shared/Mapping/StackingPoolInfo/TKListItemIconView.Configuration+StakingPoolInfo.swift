import KeeperCore
import TKCore
import TKUIKit
import UIKit

extension TKListItemIconView.Configuration {
    static func configuration(poolInfo: StackingPoolInfo?) -> TKListItemIconView.Configuration {
        return TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: .image(.TKCore.Icons.Size44.tonLogo))),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44),
            badge: Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(.image(poolInfo?.icon)),
                    size: .small
                ),
                position: .bottomRight
            )
        )
    }
}
