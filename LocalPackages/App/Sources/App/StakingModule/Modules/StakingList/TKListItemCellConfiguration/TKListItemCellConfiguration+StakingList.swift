import TKUIKit
import UIKit

extension StakingList {
    static func mapListItemConfiguration(
        title: String,
        image: TKImage,
        tag: String?,
        caption: String?
    ) -> TKListItemCell.Configuration {
        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: image, size: .size(CGSize(width: 44, height: 44)))),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44)
        )

        var tags = [TKTagView.Configuration]()
        if let tag {
            tags.append(.accentTag(text: tag, color: .Accent.green))
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
