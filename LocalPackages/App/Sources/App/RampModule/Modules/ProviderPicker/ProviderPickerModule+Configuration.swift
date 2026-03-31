import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

enum ProviderPickerModule {
    static func mapItemConfiguration(item: ProviderPickerItem) -> TKListItemCell.Configuration {
        let tags: [TKTagView.Configuration] = item.best
            ? [.accentTag(text: TKLocales.Ramp.InsertAmount.bestBadge.uppercased(), color: .Accent.blue)]
            : []

        let iconConfig = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(
                image: .urlImage(URL(string: item.merchant.image)),
                size: .size(CGSize(width: 44, height: 44)),
                corners: .cornerRadius(cornerRadius: 12)
            )),
            alignment: .center,
            cornerRadius: 12,
            size: CGSize(width: 44, height: 44)
        )

        var captionConfigs: [TKListItemTextView.Configuration] = []
        if let rateText = item.rateText {
            captionConfigs.append(
                TKListItemTextView.Configuration(
                    text: rateText,
                    color: .Text.secondary,
                    textStyle: .body2,
                    numberOfLines: 0
                )
            )
        }
        if let amountLimitText = item.amountLimitText {
            captionConfigs.append(
                TKListItemTextView.Configuration(
                    text: amountLimitText,
                    color: .Text.secondary,
                    textStyle: .body2,
                    numberOfLines: 0
                )
            )
        }

        let contentConfig = TKListItemContentView.Configuration(
            iconViewConfiguration: iconConfig,
            textContentViewConfiguration: TKListItemTextContentView.Configuration(
                titleViewConfiguration: TKListItemTitleView.Configuration(
                    title: item.merchant.title,
                    tags: tags
                ),
                captionViewsConfigurations: captionConfigs
            )
        )

        return TKListItemCell.Configuration(listItemContentViewConfiguration: contentConfig)
    }
}
