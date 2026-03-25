import KeeperCore
import TKUIKit
import UIKit

extension BuySellList {
    static func mapListItemConfiguration(item: FiatMethodItem) -> TKListItemCell.Configuration {
        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .image(
                TKImageView.Model(
                    image: .urlImage(item.iconURL),
                    tintColor: .clear,
                    size: .size(CGSize(width: 44, height: 44)),
                    corners: .cornerRadius(cornerRadius: 12)
                )
            ),
            alignment: .center,
            cornerRadius: 12,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44)
        )

        let textContentViewConfiguration = TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
                title: item.title
            ),
            captionViewsConfigurations: [
                TKListItemTextView.Configuration(
                    text: item.description,
                    color: .Text.secondary,
                    textStyle: .body2,
                    lineBreakMode: .byWordWrapping,
                    numberOfLines: 0
                ),
            ]
        )

        let listItemContentViewConfiguration = TKListItemContentView.Configuration(
            iconViewConfiguration: iconViewConfiguration,
            textContentViewConfiguration: textContentViewConfiguration
        )

        return TKListItemCell.Configuration(
            listItemContentViewConfiguration: listItemContentViewConfiguration
        )
    }
}
