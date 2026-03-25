import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

struct BalanceItemMapper {
    private let amountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    func mapTonItem(
        _ item: ProcessedBalanceTonItem,
        isSecure: Bool,
        isPinned: Bool
    ) -> TKListItemContentView.Configuration {
        let caption = createPriceSubtitle(
            price: item.price,
            currency: item.currency,
            diff: item.diff,
            isUnverified: false
        )

        return TKListItemContentView.Configuration(
            iconViewConfiguration: .tonConfiguration(),
            textContentViewConfiguration: createTextContentViewConfiguration(
                title: TonInfo.symbol,
                isPinned: isPinned,
                caption: caption,
                amount: BigUInt(item.amount),
                amountFractionDigits: TonInfo.fractionDigits,
                convertedAmount: item.converted,
                currency: item.currency,
                isSecure: isSecure
            )
        )
    }

    func mapJettonItem(
        _ item: ProcessedBalanceJettonItem,
        isSecure: Bool = false,
        isPinned: Bool = false,
        isNetworkBadgeVisible: Bool
    ) -> TKListItemContentView.Configuration {
        let caption = createPriceSubtitle(
            price: item.price,
            currency: item.currency,
            diff: item.diff,
            isUnverified: item.jetton.jettonInfo.isUnverified
        )
        var tags = [TKTagView.Configuration]()
        if let tag = item.tag {
            tags.append(TKTagView.Configuration.tag(text: tag))
        }

        return TKListItemContentView.Configuration(
            iconViewConfiguration: .configuration(
                jettonInfo: item.jetton.jettonInfo,
                isNetworkBadgeVisible: isNetworkBadgeVisible
            ),
            textContentViewConfiguration: createTextContentViewConfiguration(
                title: item.jetton.jettonInfo.symbol ?? item.jetton.jettonInfo.name,
                isPinned: isPinned,
                caption: caption,
                amount: item.amount,
                amountFractionDigits: item.fractionalDigits,
                convertedAmount: item.converted,
                currency: item.currency,
                tags: tags,
                isSecure: isSecure
            )
        )
    }

    func mapTronUSDTItem(
        item: ProcessedBalanceTronUSDTItem,
        isSecure: Bool = false,
        isPinned: Bool = false
    ) -> TKListItemContentView.Configuration {
        let caption = createPriceSubtitle(
            price: item.price,
            currency: item.currency,
            diff: item.diff,
            isUnverified: false
        )
        return TKListItemContentView.Configuration(
            iconViewConfiguration: .tronUSDTConfiguration(),
            textContentViewConfiguration: createTextContentViewConfiguration(
                title: TronSwift.USDT.symbol,
                isPinned: isPinned,
                caption: caption,
                amount: item.amount,
                amountFractionDigits: item.fractionalDigits,
                convertedAmount: item.converted,
                currency: item.currency,
                tags: [.tag(text: TronSwift.USDT.tag)],
                isSecure: isSecure
            )
        )
    }

    func mapEthenaItem(
        item: ProcessedBalanceEthenaItem,
        isSecure: Bool = false,
        isPinned: Bool = false
    ) -> TKListItemContentView.Configuration {
        let caption = createPriceSubtitle(
            price: item.price,
            currency: item.currency,
            diff: item.diff,
            isUnverified: false
        )

        return TKListItemContentView.Configuration(
            iconViewConfiguration: .ethenaConfiguration(),
            textContentViewConfiguration: createTextContentViewConfiguration(
                title: USDe.symbol,
                isPinned: isPinned,
                caption: caption,
                amount: item.amount.isZero ? nil : item.amount,
                amountFractionDigits: USDe.fractionDigits,
                convertedAmount: item.converted,
                currency: item.currency,
                isSecure: isSecure
            )
        )
    }

    func mapStakingItem(
        _ item: ProcessedBalanceStakingItem,
        isSecure: Bool,
        isPinned: Bool
    ) -> TKListItemContentView.Configuration {
        return TKListItemContentView.Configuration(
            iconViewConfiguration: .configuration(poolInfo: item.poolInfo),
            textContentViewConfiguration: createTextContentViewConfiguration(
                title: TKLocales.BalanceList.StakingItem.title,
                isPinned: isPinned,
                caption: item.poolInfo?.name.withTextStyle(.body2, color: .Text.secondary),
                amount: BigUInt(item.info.amount),
                amountFractionDigits: TonInfo.fractionDigits,
                convertedAmount: item.amountConverted,
                currency: item.currency,
                isSecure: isSecure
            )
        )
    }

    func createTextContentViewConfiguration(
        title: String,
        isPinned: Bool,
        caption: NSAttributedString?,
        amount: BigUInt?,
        amountFractionDigits: Int,
        convertedAmount: Decimal,
        currency: Currency,
        tags: [TKTagView.Configuration] = [],
        isSecure: Bool
    ) -> TKListItemTextContentView.Configuration {
        var icon: TKListItemTitleView.Configuration.Icon?
        if isPinned {
            icon = TKListItemTitleView.Configuration.Icon(image: .TKUIKit.Icons.Size12.pin, tintColor: .Icon.tertiary)
        }
        let titleViewConfiguration = TKListItemTitleView.Configuration(title: title, tags: tags, icon: icon)

        var captionViewsConfigurations = [TKListItemTextView.Configuration]()
        if let caption {
            captionViewsConfigurations.append(TKListItemTextView.Configuration(text: caption))
        }

        var valueViewConfiguration: TKListItemTextView.Configuration?
        var valueCaptionViewConfiguration: TKListItemTextView.Configuration?
        if let amount {
            let formatAmount = amountFormatter.format(
                amount: amount,
                fractionDigits: amountFractionDigits
            )

            let formatConvertedAmount = amountFormatter.format(
                decimal: convertedAmount,
                accessory: .currency(currency),
                style: .compact
            )

            let value = (isSecure ? String.secureModeValueShort : formatAmount).withTextStyle(
                .label1,
                color: .Text.primary,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
            let valueCaption = (isSecure ? String.secureModeValueShort : formatConvertedAmount).withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )

            valueViewConfiguration = TKListItemTextView.Configuration(text: value)
            valueCaptionViewConfiguration = TKListItemTextView.Configuration(text: valueCaption)
        }

        return TKListItemTextContentView.Configuration(
            titleViewConfiguration: titleViewConfiguration,
            captionViewsConfigurations: captionViewsConfigurations,
            valueViewConfiguration: valueViewConfiguration,
            valueCaptionViewConfiguration: valueCaptionViewConfiguration
        )
    }

    func createPriceSubtitle(
        price: Decimal?,
        currency: Currency,
        diff: String?,
        isUnverified: Bool
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if isUnverified {
            result.append(
                TKLocales.Token.unverified.withTextStyle(
                    .body2,
                    color: .Accent.orange,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail
                )
            )
        } else {
            if let price {
                result.append(
                    amountFormatter.format(
                        decimal: price,
                        accessory: .currency(currency),
                        style: .compact
                    ).withTextStyle(
                        .body2,
                        color: .Text.secondary,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    )
                )
                result.append(" ".withTextStyle(.body2, color: .Text.secondary))
            }

            if let diff {
                result.append({
                    let color: UIColor
                    if diff.hasPrefix("-") || diff.hasPrefix("−") {
                        color = .Accent.red
                    } else if diff.hasPrefix("+") {
                        color = .Accent.green
                    } else {
                        color = .Text.tertiary
                    }
                    return diff.withTextStyle(.body2, color: color, alignment: .left)
                }())
            }
        }
        return result
    }
}
