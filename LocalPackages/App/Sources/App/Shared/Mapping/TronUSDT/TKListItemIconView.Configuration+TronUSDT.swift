import TKUIKit
import TronSwift
import UIKit

extension TKListItemIconView.Configuration {
    static func tronUSDTConfiguration() -> TKListItemIconView.Configuration {
        return TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(
                image: .image(.TKUIKit.Icons.Size44.currencyUsdt),
                size: .size(CGSize(width: 44, height: 44)),
                corners: .circle
            )),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44),
            badge: Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(.image(.TKUIKit.Icons.Size44.currencyTrc20)),
                    size: .small
                ),
                position: .bottomRight
            )
        )
    }
}
