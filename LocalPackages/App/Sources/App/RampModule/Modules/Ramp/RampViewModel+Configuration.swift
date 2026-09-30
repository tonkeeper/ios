import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

extension RampViewModelImplementation {
    private var fiatCurrencyBlockHeading: String {
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.fiatCurrencyBlockHeading
        case .withdraw: return TKLocales.Ramp.Withdraw.fiatCurrencyBlockHeading
        }
    }

    private var fiatCurrencyRowCaption: String {
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.fiatCurrencyRowCaption
        case .withdraw: return TKLocales.Ramp.Withdraw.fiatCurrencyRowCaption
        }
    }

    func buildSnapshot() {
        var snapshot = RampViewController.Snapshot()

        let showsCurrencyShimmer = state == .loading && currentFiatCurrency == nil
        let model = RampFiatCurrencyCell.Model(
            headingTitle: fiatCurrencyBlockHeading,
            rowCaption: fiatCurrencyRowCaption,
            currencyCode: currentFiatCurrency?.code,
            currencyImage: currentFiatCurrency.flatMap { URL(string: $0.image) },
            showsCurrencyShimmer: showsCurrencyShimmer
        )
        snapshot.appendSections([.fiatCurrency])
        snapshot.appendItems([.fiatCurrencyPicker(model)], toSection: .fiatCurrency)

        snapshot.appendSections([.action])
        snapshot.appendItems([actionItem], toSection: .action)

        if state == .loading {
            snapshot.appendSections([.tokensList])
            snapshot.appendItems([.shimmer], toSection: .tokensList)
        } else if state == .failed {
            snapshot.appendSections([.retryPlaceholder])
            snapshot.appendItems([.retry], toSection: .retryPlaceholder)
        } else {
            let tokenItems = buildTokenItems()
            if !tokenItems.isEmpty {
                snapshot.appendSections([.tokensList])
                snapshot.appendItems(tokenItems, toSection: .tokensList)
            }
        }

        didUpdateSnapshot?(snapshot)
    }

    var actionItem: RampViewController.Item {
        let title: String
        let subtitle: String
        let image: UIImage
        switch flow {
        case .deposit:
            title = TKLocales.Ramp.Deposit.receiveTokens
            subtitle = TKLocales.Ramp.Deposit.receiveTokensSubtitle
            image = .TKUIKit.Icons.Size28.qrCode
        case .withdraw:
            title = TKLocales.Ramp.Withdraw.sendTokens
            subtitle = TKLocales.Ramp.Withdraw.sendTokensSubtitle
            image = .TKUIKit.Icons.Size28.trayArrowUp
        }

        let iconConfig = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(
                image: .image(image),
                tintColor: .Accent.blue,
                size: .size(CGSize(width: 28, height: 28))
            )),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Accent.blue.withAlphaComponent(0.16),
            size: CGSize(width: 44, height: 44)
        )
        let configuration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: iconConfig,
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: title.withTextStyle(.label1, color: .Text.primary),
                        numberOfLines: 0
                    ),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(
                            text: subtitle,
                            color: .Text.secondary,
                            textStyle: .body2,
                            numberOfLines: 0
                        ),
                    ]
                )
            )
        )

        switch flow {
        case .deposit: return .receiveTokens(configuration)
        case .withdraw: return .sendTokens(configuration)
        }
    }

    func buildTokenItems() -> [RampViewController.Item] {
        onRampLayout?.items.compactMap { item in
            guard let assets = item.assets, !assets.isEmpty else {
                return nil
            }
            return .item(
                item: item,
                configuration: RampItemCell.Configuration(
                    listItemContentViewConfiguration: RampItemContentView.Configuration(
                        iconViewConfiguration: iconConfiguration(for: item),
                        titleViewConfiguration: TKListItemTitleView.Configuration(
                            title: item.title.withTextStyle(.label1, color: .Text.primary),
                            numberOfLines: 0
                        ),
                        captionViewConfiguration: .init(text: item.itemDescription, iconURLs: [])
                    )
                )
            )
        } ?? []
    }

    func iconConfiguration(for item: OnRampLayoutItem) -> TKListItemIconView.Configuration {
        return TKListItemIconView.Configuration(
            content: .image(
                TKImageView.Model(
                    image: .urlImage(URL(string: item.image)),
                    size: .size(CGSize(width: 44, height: 44)),
                    corners: .circle
                )
            ),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44)
        )
    }
}

enum RampItemConfigurator {
    static let hiddenNetworkIdentifiers: Set<String> = ["jetton", "native"]

    static func networkLabel(network: String, networkName: String) -> String {
        hiddenNetworkIdentifiers.contains(network.lowercased()) ? networkName : network
    }

    static func isTron(network: String) -> Bool {
        ["trc20", "trc-20"].contains(network.lowercased())
    }

    static func tags(network: String, networkName: String) -> [TKTagView.Configuration] {
        if hiddenNetworkIdentifiers.contains(network.lowercased()), networkName.uppercased() != TonInfo.symbol {
            return []
        }

        let color: UIColor
        let text: String

        if isTron(network: network) {
            color = .Accent.red
            text = network
        } else if networkName.uppercased() == TonInfo.symbol {
            color = .Accent.blue
            text = networkName
        } else {
            color = .Text.secondary
            text = network
        }

        return [.accentTag(text: text, color: color)]
    }

    static func badge(for asset: RampAsset, size: TKListItemBadgeView.Configuration.Size = .small) -> TKListItemIconView.Configuration.Badge? {
        if asset.network == TonToken.ton.symbol {
            return nil
        }

        return TKListItemIconView.Configuration.Badge(
            configuration: TKListItemBadgeView.Configuration(
                item: .image(.urlImage(URL(string: asset.networkImage))),
                size: size
            ),
            position: .bottomRight
        )
    }
}
