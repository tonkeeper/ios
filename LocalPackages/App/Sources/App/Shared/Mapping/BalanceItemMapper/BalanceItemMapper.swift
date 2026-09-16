import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

struct BalanceItemMapper {
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
        var configuration = amountFormatter.config
        configuration.signPolicy = .always
        self.signedAmountFormatter = AmountFormatter(configuration: configuration)
    }

    func mapTonItem(
        _ item: ProcessedBalanceTonItem,
        tags: [TKTagView.Configuration] = [],
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
                tags: tags,
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

    func mapTronTRXItem(
        item: ProcessedBalanceTronTRXItem,
        isSecure: Bool = false
    ) -> TKListItemContentView.Configuration {
        let caption = createPriceSubtitle(
            price: item.price,
            currency: item.currency,
            diff: item.diff,
            isUnverified: false
        )
        return TKListItemContentView.Configuration(
            iconViewConfiguration: .tronTRXConfiguration(),
            textContentViewConfiguration: createTextContentViewConfiguration(
                title: TronSwift.TRX.symbol,
                isPinned: false,
                caption: caption,
                amount: item.amount,
                amountFractionDigits: item.fractionalDigits,
                convertedAmount: item.converted,
                currency: item.currency,
                tags: [],
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
                accessory: .fiat(currency),
                style: .fiatBalance
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
                        accessory: .fiat(currency),
                        style: .fiatBalance
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
                let formattedDiff = formatDiff(diff) ?? diff
                result.append({
                    let color: UIColor
                    if formattedDiff.hasPrefix("-") || formattedDiff.hasPrefix("−") {
                        color = .Accent.red
                    } else if formattedDiff.hasPrefix("+") {
                        color = .Accent.green
                    } else {
                        color = .Text.tertiary
                    }
                    return formattedDiff.withTextStyle(.body2, color: color, alignment: .left)
                }())
            }
        }
        return result
    }

    private func formatDiff(_ diff: String) -> String? {
        guard let decimal = decimalValue(from: diff) else {
            return nil
        }

        return signedAmountFormatter.format(decimal: decimal, style: .percent)
    }

    private func decimalValue(from value: String) -> Decimal? {
        let normalized = value
            .replacingOccurrences(of: String.Symbol.minus, with: "-")
            .replacingOccurrences(of: String.Symbol.plus, with: "+")
            .filter { "0123456789.,+-".contains($0) }

        guard !normalized.isEmpty else {
            return nil
        }

        let signedNormalized = normalized.dropFirstSign()
        guard signedNormalized.value.contains(where: { "0123456789".contains($0) }) else {
            return nil
        }

        let decimalSeparatorIndex = signedNormalized.value.lastIndex {
            $0 == "." || $0 == ","
        }

        let decimalString: String
        if let decimalSeparatorIndex {
            let integer = signedNormalized.value[..<decimalSeparatorIndex]
                .filter { "0123456789".contains($0) }
            let fraction = signedNormalized.value[signedNormalized.value.index(after: decimalSeparatorIndex)...]
                .filter { "0123456789".contains($0) }
            let integerPart = integer.isEmpty ? "0" : integer
            decimalString = signedNormalized.sign + integerPart + (fraction.isEmpty ? "" : "." + fraction)
        } else {
            decimalString = signedNormalized.sign + signedNormalized.value
        }

        return Decimal(
            string: decimalString,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

private extension String {
    func dropFirstSign() -> (sign: String, value: String) {
        guard let first else {
            return ("", self)
        }

        switch first {
        case "-", "+":
            return (String(first), String(dropFirst()))
        default:
            return ("", self)
        }
    }
}
