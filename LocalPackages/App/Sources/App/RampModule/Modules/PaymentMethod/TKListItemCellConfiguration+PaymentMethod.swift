import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

extension PaymentMethodModule {
    static func mapItemConfiguration(item: PaymentMethodViewController.Item) -> TKListItemCell.Configuration? {
        switch item {
        case let .cashMethod(method):
            return mapCashMethodConfiguration(method: method)
        case let .cryptoAsset(method):
            return mapCryptoAssetConfiguration(method: method)
        case .allMethods, .allAssets, .shimmer, .stablecoin:
            return nil
        }
    }

    static func mapStablecoinItemConfiguration(item: PaymentMethodViewController.Item) -> PaymentMethodStablecoinCell.Configuration? {
        guard case let .stablecoin(symbol, image, networkMethods) = item else { return nil }
        return mapStablecoinConfiguration(symbol: symbol, image: image, networkMethods: networkMethods)
    }

    private static func mapStablecoinConfiguration(symbol: String, image: String?, networkMethods: [OnRampLayoutCryptoMethod]) -> PaymentMethodStablecoinCell.Configuration {
        let image: TKImage? = URL(string: image ?? "").map { .urlImage($0) }
        let networkIconURLs = networkMethods.compactMap { URL(string: $0.networkImage) }
        return PaymentMethodStablecoinCell.Configuration(
            contentConfiguration: PaymentMethodStablecoinContentView.Configuration(
                image: image,
                title: symbol,
                networkIconURLs: networkIconURLs
            )
        )
    }

    static func mapCashMethodConfiguration(method: OnRampLayoutCashMethod) -> TKListItemCell.Configuration {
        let iconConfig = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(
                image: .urlImage(URL(string: method.image)),
                size: .size(CGSize(width: 28, height: 28)),
                corners: .circle
            )),
            alignment: .center,
            cornerRadius: 14,
            size: CGSize(width: 28, height: 28)
        )

        return TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: iconConfig,
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: method.name)
                )
            )
        )
    }

    private static func mapCryptoAssetConfiguration(method: OnRampLayoutCryptoMethod) -> TKListItemCell.Configuration {
        RampPicker.mapCryptoItemConfiguration(
            symbol: method.symbol,
            networkName: method.networkName,
            network: method.network,
            image: .urlImage(URL(string: method.image))
        )
    }

    static func mapAllItemsConfiguration(item: PaymentMethodViewController.Item) -> PaymentMethodAllItemsCell.Configuration? {
        switch item {
        case let .allMethods(first, second):
            return PaymentMethodAllItemsCell.Configuration(
                contentConfiguration: PaymentMethodAllItemsContentView.Configuration(
                    leftImage: .urlImage(URL(string: first.image)),
                    rightImage: .urlImage(URL(string: second.image)),
                    title: TKLocales.Ramp.PaymentMethod.allMethods
                )
            )
        case let .allAssets(first, second):
            return PaymentMethodAllItemsCell.Configuration(
                contentConfiguration: PaymentMethodAllItemsContentView.Configuration(
                    leftImage: .urlImage(URL(string: first.image)),
                    rightImage: .urlImage(URL(string: second.image)),
                    title: TKLocales.Ramp.PaymentMethod.allAssets
                )
            )
        case .shimmer, .cashMethod, .cryptoAsset, .stablecoin:
            return nil
        }
    }
}
