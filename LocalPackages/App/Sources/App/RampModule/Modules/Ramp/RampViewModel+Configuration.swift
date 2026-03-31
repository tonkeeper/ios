import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

extension RampViewModelImplementation {
    func buildSnapshot() {
        var snapshot = RampViewController.Snapshot()

        snapshot.appendSections([.action])
        snapshot.appendItems([actionItem], toSection: .action)

        if isOnRampLayoutLoading {
            snapshot.appendSections([.tokensList])
            snapshot.appendItems([.shimmer], toSection: .tokensList)
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
            backgroundColor: .Accent.blue.withAlphaComponent(0.12),
            size: CGSize(width: 44, height: 44)
        )
        let configuration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: iconConfig,
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
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

    var sectionHeaderTitle: String {
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.depositWithCashOrCrypto
        case .withdraw: return TKLocales.Ramp.Withdraw.withdrawToCashOrCrypto
        }
    }

    func buildTokenItems() -> [RampViewController.Item] {
        return onRampLayout?.assets.map { asset in
            .tokenItem(
                asset: asset,
                configuration: RampItemCell.Configuration(
                    listItemContentViewConfiguration: RampItemContentView.Configuration(
                        iconViewConfiguration: iconConfiguration(for: asset),
                        titleViewConfiguration: TKListItemTitleView.Configuration(
                            title: asset.symbol,
                            tags: tags(for: asset)
                        ),
                        captionViewConfiguration: captionConfiguration(for: asset)
                    )
                )
            )
        } ?? []
    }

    func captionConfiguration(for asset: RampAsset) -> RampItemCaptionWithIconsView.Configuration {
        let caption: String
        let iconURLs: [URL]

        if asset.symbol == TonToken.ton.symbol {
            switch flow {
            case .deposit:
                caption = TKLocales.Ramp.Deposit.availableFromOtherCrypto
                iconURLs = asset.cryptoMethods.compactMap { URL(string: $0.image) }
            case .withdraw:
                caption = TKLocales.Ramp.Withdraw.availableForCashOut
                iconURLs = asset.cashMethods.compactMap { URL(string: $0.image) }
            }
        } else {
            caption = TKLocales.Ramp.Deposit.available1to1CrossChain

            if asset.stablecoin {
                var networkImages: [String] = []

                for cryptoMethod in asset.cryptoMethods where cryptoMethod.stablecoin {
                    if !networkImages.contains(cryptoMethod.networkImage) {
                        networkImages.append(cryptoMethod.networkImage)
                    }
                }

                iconURLs = networkImages.compactMap { URL(string: $0) }
            } else {
                iconURLs = asset.cryptoMethods.compactMap { URL(string: $0.image) }
            }
        }

        return .init(text: caption, iconURLs: iconURLs)
    }

    func iconConfiguration(for asset: RampAsset) -> TKListItemIconView.Configuration {
        let isNetworkBadgeVisible = asset.symbol != TonToken.ton.symbol
        var badge: TKListItemIconView.Configuration.Badge?
        if isNetworkBadgeVisible {
            badge = RampItemConfigurator.badge(for: asset)
        }

        return TKListItemIconView.Configuration(
            content: .image(
                TKImageView.Model(
                    image: .urlImage(URL(string: asset.image)),
                    size: .size(CGSize(width: 44, height: 44)),
                    corners: .circle
                )
            ),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44),
            badge: badge
        )
    }

    func tags(for asset: RampAsset) -> [TKTagView.Configuration] {
        guard asset.symbol != TonToken.ton.symbol else {
            return []
        }

        return RampItemConfigurator.tags(network: asset.network, networkName: asset.networkName)
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

    static func badge(for asset: RampAsset) -> TKListItemIconView.Configuration.Badge? {
        if asset.network == TonToken.ton.symbol {
            return nil
        }

        return TKListItemIconView.Configuration.Badge(
            configuration: TKListItemBadgeView.Configuration(
                item: .image(.urlImage(URL(string: asset.networkImage))),
                size: .small
            ),
            position: .bottomRight
        )
    }
}
