import TKUIKit
import UIKit

extension TokenPicker {
    enum Network {
        case ton
        case trc20
    }

    static func mapListBalanceItemConfiguration(
        title: String,
        image: TKImage,
        tag: String?,
        caption: String?,
        network: Network? = nil
    ) -> TKListItemCell.Configuration {
        var badge: TKListItemIconView.Configuration.Badge?
        if let network {
            switch network {
            case .ton:
                badge = TKListItemIconView.Configuration.Badge(
                    configuration: TKListItemBadgeView.Configuration(
                        item: .image(.image(.App.Currency.Vector.ton)),
                        size: .small
                    ),
                    position: .bottomRight
                )
            case .trc20:
                badge = TKListItemIconView.Configuration.Badge(
                    configuration: TKListItemBadgeView.Configuration(
                        item: .image(.image(.App.Currency.Vector.trc20)),
                        size: .small
                    ),
                    position: .bottomRight
                )
            }
        }

        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: image, size: .size(CGSize(width: 44, height: 44)))),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44),
            badge: badge
        )

        var tags = [TKTagView.Configuration]()
        if let tag {
            tags.append(.accentTag(text: tag, color: .Accent.blue))
        }

        let textContentViewConfiguration = TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
                title: title,
                tags: tags
            ),
            captionViewsConfigurations: [
                TKListItemTextView.Configuration(
                    text: caption,
                    color: .Text.secondary,
                    textStyle: .body2
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

    static func mapListNameItemConfiguration(
        title: String,
        image: TKImage,
        tag: String?,
        caption: String?,
        network: Network? = nil
    ) -> TKListItemCell.Configuration {
        var badge: TKListItemIconView.Configuration.Badge?
        if let network {
            switch network {
            case .ton:
                badge = TKListItemIconView.Configuration.Badge(
                    configuration: TKListItemBadgeView.Configuration(
                        item: .image(.image(.App.Currency.Vector.ton)),
                        size: .small
                    ),
                    position: .bottomRight
                )
            case .trc20:
                badge = TKListItemIconView.Configuration.Badge(
                    configuration: TKListItemBadgeView.Configuration(
                        item: .image(.image(.App.Currency.Vector.trc20)),
                        size: .small
                    ),
                    position: .bottomRight
                )
            }
        }

        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: image, size: .size(CGSize(width: 44, height: 44)))),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44),
            badge: badge
        )

        var tags = [TKTagView.Configuration]()
        if let tag {
            tags.append(.accentTag(text: tag, color: .Accent.blue))
        }

        let textContentViewConfiguration = TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
                title: title,
                caption: caption,
                tags: tags
            )
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
