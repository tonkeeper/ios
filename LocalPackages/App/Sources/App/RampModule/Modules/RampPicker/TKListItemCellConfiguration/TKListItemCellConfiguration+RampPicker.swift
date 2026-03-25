import KeeperCore
import TKUIKit
import UIKit

extension RampPicker {
    static func mapCurrencyItemConfiguration(
        currency: RemoteCurrency,
        iconImage: TKImage?
    ) -> TKListItemCell.Configuration {
        let image = iconImage ?? .image(.TKUIKit.Icons.Size16.globe)
        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: image, size: .size(CGSize(width: 28, height: 28)))),
            alignment: .center,
            cornerRadius: 14,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 28, height: 28)
        )

        let textContentViewConfiguration = TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
                title: currency.code,
                caption: currency.name
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

    static func mapCryptoItemConfiguration(
        symbol: String,
        networkName: String,
        network: String,
        image: TKImage?
    ) -> TKListItemCell.Configuration {
        let iconImage = image ?? .image(.TKUIKit.Icons.Size16.globe)
        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: iconImage, size: .size(CGSize(width: 28, height: 28)))),
            alignment: .center,
            cornerRadius: 14,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 28, height: 28)
        )

        let tags = RampItemConfigurator.tags(network: network, networkName: networkName)

        let textContentViewConfiguration = TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
                title: symbol,
                caption: networkName,
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

    static func mapNetworkItemConfiguration(
        network: String,
        networkName: String?,
        image: TKImage?,
        feeText: String? = nil
    ) -> TKListItemCell.Configuration {
        let iconImage = image ?? .image(.TKUIKit.Icons.Size16.globe)
        let iconViewConfiguration = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: iconImage, size: .size(CGSize(width: 28, height: 28)))),
            alignment: .center,
            cornerRadius: 14,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 28, height: 28)
        )

        let valueConfig: TKListItemTextView.Configuration? = feeText.map {
            TKListItemTextView.Configuration(
                text: $0,
                color: .Text.secondary,
                textStyle: .body1,
                numberOfLines: 1
            )
        }

        let title: String
        let caption: String?
        if let networkName {
            title = networkName
            caption = RampItemConfigurator.networkLabel(network: network, networkName: networkName)
        } else {
            title = network
            caption = nil
        }

        let textContentViewConfiguration = TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
                title: title,
                caption: caption
            ),
            valueViewConfiguration: valueConfig
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
