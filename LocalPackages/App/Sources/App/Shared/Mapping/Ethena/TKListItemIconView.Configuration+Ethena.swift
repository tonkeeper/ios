import TKUIKit
import TronSwift
import UIKit

extension TKListItemIconView.Configuration {
    static func ethenaConfiguration() -> TKListItemIconView.Configuration {
        return TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(
                image: .image(.App.Currency.Size44.usde),
                size: .size(CGSize(width: 44, height: 44)),
                corners: .circle
            )),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44)
        )
    }
}
