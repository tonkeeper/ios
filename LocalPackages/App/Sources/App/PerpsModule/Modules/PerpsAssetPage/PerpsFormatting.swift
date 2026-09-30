import Foundation
import KeeperCore
import TKLocalize

enum PerpsFormatting {
    static func usd(_ value: Double) -> String {
        formatUsd(Decimal(value), formatter: amountFormatter)
    }

    static func usd(_ decimalString: String) -> String {
        formatUsd(decimal(from: decimalString), formatter: amountFormatter)
    }

    static func usdWhole(_ value: Double) -> String {
        amountFormatter.format(
            decimal: rounded(Decimal(value), scale: 0),
            accessory: .fiat(Currency.USD),
            style: .exactValue
        )
    }

    static func signedUsd(_ value: Double) -> String {
        let magnitude = formatUsd(abs(Decimal(value)), formatter: amountFormatter)
        if value > 0 { return String.Symbol.plus + signSpace + magnitude }
        if value < 0 { return String.Symbol.minus + signSpace + magnitude }
        return magnitude
    }

    static func signedPercent(_ value: Double) -> String {
        signedAmountFormatter.format(decimal: Decimal(value), style: .percent)
    }

    static func funding(percent value: Double) -> String {
        let formatted = fundingFormatter.format(decimal: rounded(Decimal(value), scale: 8), style: .exactValue)
        return formatted + String.Symbol.shortSpace + "%"
    }

    static func candleDateTime(_ date: Date) -> String {
        candleDateFormatter.string(from: date)
    }

    static func token(_ value: Double, symbol: String, decimals: Int) -> String {
        let scale = max(0, min(decimals, 8))
        let formatted = exactFormatter.format(decimal: rounded(Decimal(value), scale: scale), style: .exactValue)
        return symbol.isEmpty ? formatted : formatted + " " + symbol
    }

    static func plain(_ decimalString: String) -> String {
        guard !decimalString.isEmpty else { return "" }
        return exactFormatter.format(decimal: decimal(from: decimalString), style: .exactValue)
    }

    static func leverage(_ value: Double) -> String {
        let scale = value == value.rounded() ? 0 : 1
        return exactFormatter.format(decimal: rounded(Decimal(value), scale: scale), style: .exactValue) + "x"
    }

    static func leverageBadge(_ value: Double) -> String {
        leverage(value).uppercased()
    }

    static func autoCloseSummary(_ autoClose: PerpsAutoClose) -> String? {
        var parts: [String] = []
        if let takeProfit = autoClose.takeProfit { parts.append("\(usd(takeProfit.triggerPrice)) TP") }
        if let stopLoss = autoClose.stopLoss { parts.append("\(usd(stopLoss.triggerPrice)) SL") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Helpers

    private static let candleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMM HH:mm")
        return formatter
    }()

    private static func formatUsd(_ value: Decimal, formatter: AmountFormatter) -> String {
        formatter.format(decimal: value, accessory: .fiat(Currency.USD), style: .compact)
    }

    private static func decimal(from string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }

    private static let signSpace = " "

    private static let exactFormatter = AmountFormatter(configuration: .init())
    private static let amountFormatter = AmountFormatter(configuration: .init())
    private static let signedAmountFormatter = AmountFormatter(configuration: .init(signPolicy: .always))
    private static let fundingFormatter = AmountFormatter(configuration: .init(signPolicy: .negativeOnly))
}
