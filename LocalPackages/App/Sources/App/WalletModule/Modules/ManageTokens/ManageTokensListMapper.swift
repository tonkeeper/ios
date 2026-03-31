import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

struct ManageTokensListMapper {
    private let amountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    func mapTonItem(_ item: BalanceTonItemModel) -> TKListItemCell.Configuration {
        let amount = amountFormatter.format(
            amount: item.amount,
            fractionDigits: item.fractionalDigits,
            accessory: .symbol(TonInfo.symbol)
        )

        return TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: .tonConfiguration(),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: TonInfo.symbol),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(text: amount, color: .Text.secondary, textStyle: .body2),
                    ]
                )
            )
        )
    }

    func mapJettonItem(
        _ item: BalanceJettonItemModel,
        isNetworkBadgeVisible: Bool
    ) -> TKListItemCell.Configuration {
        let captionConfiguration: TKListItemTextView.Configuration
        if item.jetton.jettonInfo.isUnverified {
            captionConfiguration = .init(
                text: TKLocales.Token.unverified,
                color: .Accent.orange,
                textStyle: .body2
            )
        } else {
            let amount = amountFormatter.format(
                amount: item.amount,
                fractionDigits: item.fractionalDigits,
                accessory: item.jetton.jettonInfo.symbol.flatMap { .symbol($0) } ?? .none
            )
            captionConfiguration = .init(
                text: amount,
                color: .Text.secondary,
                textStyle: .body2
            )
        }

        var tags = [TKTagView.Configuration]()
        if let tag = item.tag {
            tags.append(.tag(text: tag))
        }

        return TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: .configuration(
                    jettonInfo: item.jetton.jettonInfo,
                    isNetworkBadgeVisible: isNetworkBadgeVisible
                ),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: item.jetton.jettonInfo.symbol ?? item.jetton.jettonInfo.name,
                        tags: tags
                    ),
                    captionViewsConfigurations: [captionConfiguration]
                )
            )
        )
    }

    func mapStakingItem(_ item: BalanceStakingItemModel) -> TKListItemCell.Configuration {
        let amount = amountFormatter.format(
            amount: BigUInt(item.info.amount),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .symbol(TonInfo.symbol)
        )

        return TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: .configuration(poolInfo: item.poolInfo),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: item.poolInfo?.name ?? ""),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(text: amount, color: .Text.secondary, textStyle: .body2),
                    ]
                )
            )
        )
    }

    func mapTronUSDTItem(_ item: BalanceTronUSDTItemModel) -> TKListItemCell.Configuration {
        let amount = amountFormatter.format(
            amount: item.amount,
            fractionDigits: item.fractionalDigits,
            accessory: .symbol(USDT.symbol)
        )

        var tags = [TKTagView.Configuration]()
        if let tag = item.tag {
            tags.append(.tag(text: tag))
        }

        return TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: .tronUSDTConfiguration(),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: USDT.symbol, tags: tags),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(text: amount, color: .Text.secondary, textStyle: .body2),
                    ]
                )
            )
        )
    }
}
