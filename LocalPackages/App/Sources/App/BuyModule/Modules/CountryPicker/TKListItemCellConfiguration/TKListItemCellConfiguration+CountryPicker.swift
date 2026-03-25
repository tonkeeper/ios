import TKUIKit
import UIKit

extension CountryPicker {
    static func mapListItemConfiguration(
        title: String,
        caption: String?,
        emoji: String
    ) -> TKListItemCell.Configuration {
        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .text(
                TKListItemIconView.Configuration.TextContent(
                    text: emoji,
                    font: .systemFont(ofSize: 24),
                    color: .white
                )
            ),
            alignment: .center,
            backgroundColor: .clear,
            size: CGSize(width: 28, height: 28)
        )

        let textContentViewConfiguration = TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
                title: title,
                caption: caption
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
