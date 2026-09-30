import BigInt
import Foundation
import KeeperCore
import TKLocalize

struct TradeAssetDetailsValueFormatter {
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter
    private let currencyProvider: () -> Currency

    init(
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter,
        currencyProvider: @escaping () -> Currency
    ) {
        self.amountFormatter = amountFormatter
        self.signedAmountFormatter = signedAmountFormatter
        self.currencyProvider = currencyProvider
    }

    func formatPrice(_ price: Decimal) -> String {
        amountFormatter.format(
            decimal: price,
            accessory: .fiat(currencyProvider()),
            style: .compact
        )
    }

    func formatSignedPrice(_ value: Decimal) -> String {
        signedAmountFormatter.format(
            decimal: value,
            accessory: .fiat(currencyProvider()),
            style: .compact
        )
    }

    func formatChange(_ value: Decimal) -> String {
        signedAmountFormatter.format(
            decimal: value,
            style: .percent
        )
    }

    func decimalValue(_ value: String) -> Decimal? {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    func calculateChangeAmount(price: Decimal, diffPercent: Decimal) -> Decimal? {
        let denominator = 100 + diffPercent
        guard denominator != 0 else {
            return nil
        }

        return (price * diffPercent) / denominator
    }

    func formatPrice(_ price: BigInt?) -> String {
        guard let price else {
            return "..."
        }

        return formattedBigInt(
            price,
            accessory: .fiat(currencyProvider()),
            formatter: amountFormatter,
            style: .compact
        )
    }

    func formatSignedPrice(_ value: BigInt?) -> String? {
        guard let value else {
            return nil
        }

        return formattedBigInt(
            value,
            accessory: .fiat(currencyProvider()),
            formatter: signedAmountFormatter,
            style: .compact
        )
    }

    func formatChange(_ value: BigInt?) -> String? {
        guard let value else {
            return nil
        }

        return formattedBigInt(
            value,
            formatter: signedAmountFormatter,
            style: .percent
        )
    }

    func earnApyValueFormatter(_ value: Decimal?) -> String? {
        guard let value else { return nil }
        return TKLocales.Trade.AssetDetails.apyValue(
            amountFormatter.format(decimal: value, style: .percent)
        )
    }

    func earnApyButtonFormatter(_ value: Decimal?) -> String? {
        guard let value else { return nil }
        return TKLocales.Trade.AssetDetails.earnApy(
            amountFormatter.format(decimal: value, style: .percent)
        )
    }

    private func formattedBigInt(
        _ value: BigInt,
        accessory: AmountAccessoryType = .none,
        formatter: AmountFormatter,
        style: AmountDisplayStyle
    ) -> String {
        formatter.format(
            amount: value.magnitude,
            fractionDigits: 0,
            accessory: accessory,
            isNegative: value.sign == .minus,
            style: style
        )
    }
}

struct TradeAssetDetailsDisplayFormatter {
    private let amountFormatter: AmountFormatter
    private let valueFormatter: TradeAssetDetailsValueFormatter
    private let currencyProvider: () -> Currency

    init(
        amountFormatter: AmountFormatter,
        valueFormatter: TradeAssetDetailsValueFormatter,
        currencyProvider: @escaping () -> Currency
    ) {
        self.amountFormatter = amountFormatter
        self.valueFormatter = valueFormatter
        self.currencyProvider = currencyProvider
    }

    func formatOverviewValue(
        _ metric: TradingAssetMetric,
        assetDecimals: Int
    ) -> String {
        switch metric {
        case let .marketCap(value, _, _):
            return formattedCompactCurrency(value) ?? value
        case let .totalSupply(value),
             let .circulatingSupply(value):
            return formattedCompactTokenAmount(
                value,
                fractionDigits: assetDecimals
            ) ?? value
        }
    }

    func formatOverviewSecondaryValue(_ metric: TradingAssetMetric) -> String? {
        guard let value = metric.secondaryValue else { return nil }
        guard let decimal = decimalValue(from: value) else {
            return value
        }
        return valueFormatter.formatChange(decimal)
    }

    func formatTradingAmount(_ value: String) -> String {
        formattedCompactCurrency(value) ?? value
    }

    func formatTradingChange(_ value: String?) -> String? {
        guard let value else { return nil }
        guard let decimal = decimalValue(from: value) else {
            return value
        }
        return valueFormatter.formatChange(decimal)
    }

    func formatTradingSide(title: String, value: String) -> String {
        let formattedValue = formattedCompactCurrency(value) ?? value
        return "\(title) · \(formattedValue)"
    }

    func isPositive(_ text: String?) -> Bool {
        guard let text, let value = decimalValue(from: text) else { return true }
        return value >= 0
    }

    func formatBalanceAmount(
        amount: BigUInt,
        fractionDigits: Int,
        symbol: String
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: .tokenSymbol(symbol),
            isNegative: false,
            style: .regular
        )
    }

    func formatBalanceConverted(_ value: Decimal?) -> String? {
        guard let value else {
            return nil
        }

        return amountFormatter.format(
            decimal: value,
            accessory: .fiat(currencyProvider()),
            style: .fiatBalance
        )
    }

    private func formattedCompactCurrency(_ value: String, currency: Currency = .USD) -> String? {
        guard let decimal = decimalValue(from: value) else {
            return nil
        }

        return withAccessory(
            formattedCompactDecimal(decimal),
            accessory: .fiat(currency)
        )
    }

    private func formattedCompactTokenAmount(_ value: String, fractionDigits: Int) -> String? {
        guard let decimal = decimalValue(from: value) else {
            return nil
        }

        let normalizedValue: Decimal
        if value.contains(".") {
            normalizedValue = decimal
        } else {
            normalizedValue = decimal / decimalPowerOfTen(fractionDigits)
        }

        return withAccessory(
            formattedCompactDecimal(normalizedValue),
            accessory: .none
        )
    }

    private func formattedCompactDecimal(_ value: Decimal) -> String {
        amountFormatter.format(
            decimal: value,
            accessory: .none,
            style: .compact
        )
    }

    private func withAccessory(
        _ value: String,
        accessory: AmountAccessoryType
    ) -> String {
        switch accessory {
        case .none:
            return value
        case let .token(currency),
             let .fiat(currency):
            return currency.symbolOnLeft
                ? "\(currency.symbol)\(value)"
                : "\(value)\(currency.symbol)"
        }
    }

    private func decimalValue(from value: String) -> Decimal? {
        let normalized = value
            .replacingOccurrences(of: String.Symbol.minus, with: "-")
            .replacingOccurrences(of: String.Symbol.plus, with: "+")
            .filter { "0123456789.+-".contains($0) }
        guard !normalized.isEmpty else {
            return nil
        }

        return Decimal(
            string: normalized,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func decimalPowerOfTen(_ power: Int) -> Decimal {
        guard power > 0 else {
            return 1
        }

        var result: Decimal = 1
        for _ in 0 ..< power {
            result *= 10
        }
        return result
    }
}
