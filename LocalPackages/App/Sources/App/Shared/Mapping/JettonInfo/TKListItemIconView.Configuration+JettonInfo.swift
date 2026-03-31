import KeeperCore
import TKCore
import TKUIKit
import UIKit

extension TKListItemIconView.Configuration {
    static func configuration(
        jettonInfo: JettonInfo,
        isNetworkBadgeVisible: Bool
    ) -> TKListItemIconView.Configuration {
        var badge: TKListItemIconView.Configuration.Badge?
        if isNetworkBadgeVisible {
            badge = Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(.image(.App.Currency.Vector.ton)),
                    size: .small
                ),
                position: .bottomRight
            )
        }

        return TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: .urlImage(jettonInfo.imageURL), size: .size(CGSize(width: 44, height: 44)), corners: .circle)),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44),
            badge: badge
        )
    }
}
