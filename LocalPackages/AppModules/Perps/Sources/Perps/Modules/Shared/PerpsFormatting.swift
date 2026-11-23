import Foundation
import PerpsModels
import TKLocalize

public struct PerpsFormatting {
    private let amounts: any PerpsAmountFormatting
    private let locale: Locale
    private let hiddenBalance: () -> String?

    public init(amounts: any PerpsAmountFormatting, locale: Locale = .current, hiddenBalance: @escaping () -> String? = { nil }) {
        self.amounts = amounts
        self.locale = locale
        self.hiddenBalance = hiddenBalance
    }

    public func input(_ text: String) -> String {
        text.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }

    public var hiddenBalanceText: String? {
        hiddenBalance()
    }

    public func usd(_ value: Double) -> String {
        amount(Self.decimal(value))
    }

    public func usd(_ decimalString: String) -> String {
        amount(Self.decimal(from: decimalString))
    }

    public func usdShort(_ value: Double) -> String {
        let decimal = Self.decimal(value)
        let magnitude = abs(decimal)
        if magnitude >= 999_995_000_000 { return TKLocales.Perps.Number.trillions(roundedUsd(decimal / 1_000_000_000_000)) }
        if magnitude >= 999_995_000 { return TKLocales.Perps.Number.billions(roundedUsd(decimal / 1_000_000_000)) }
        if magnitude >= 999_995 { return TKLocales.Perps.Number.millions(roundedUsd(decimal / 1_000_000)) }
        if Self.rounded(magnitude, scale: 2) >= 1000 { return TKLocales.Perps.Number.thousands(roundedUsd(decimal / 1000)) }
        return withCents(roundedUsd(decimal))
    }

    public func signedUsd(_ value: Double) -> String {
        let magnitude = amount(abs(Self.decimal(value)))
        if value > 0 { return String.Symbol.plus + Self.signSpace + magnitude }
        if value < 0 { return String.Symbol.minus + Self.signSpace + magnitude }
        return magnitude
    }

    public func balance(_ value: Double) -> String {
        hiddenBalance() ?? usd(value)
    }

    public func balance(_ decimalString: String) -> String {
        hiddenBalance() ?? usd(decimalString)
    }

    public func signedBalance(_ value: Double) -> String {
        hiddenBalance() ?? signedUsd(value)
    }

    public func signedPercent(_ value: Double) -> String {
        amounts.signedPercent(Self.decimal(value))
    }

    public func price(_ value: Double) -> String {
        let decimal = Self.decimal(value)
        let fractionDigits = abs(decimal) >= 1 ? 2 : min(max(-Self.rounded(decimal, scale: 6).exponent, 2), 6)
        return amounts.usdFixed(decimal, fractionDigits: fractionDigits)
    }

    public func priceChange(_ percent: Double) -> String {
        let rounded = Self.rounded(Self.decimal(percent), scale: 2)
        let sign = rounded > 0 ? String.Symbol.plus : rounded < 0 ? String.Symbol.minus : ""
        return sign + amounts.fixed(abs(rounded), fractionDigits: 2) + "%"
    }

    public func funding(percent value: Double) -> String {
        let formatted = amounts.fundingExact(Self.rounded(Self.decimal(value), scale: 8))
        return formatted + "%"
    }

    public func feeRate(percent value: Double) -> String {
        amounts.exact(Self.rounded(Self.decimal(value), scale: 4)) + "%"
    }

    public func candleDateTime(_ date: Date) -> String {
        Self.candleDateFormatter.string(from: date)
    }

    public func dayMonth(_ date: Date) -> String {
        Self.dayMonthFormatter.string(from: date)
    }

    public func token(_ value: Double, symbol: String, decimals: Int) -> String {
        let scale = max(0, min(decimals, 8))
        let formatted = amounts.exact(Self.rounded(Self.decimal(value), scale: scale))
        return symbol.isEmpty ? formatted : formatted + " " + symbol
    }

    public func tokenCompact(_ value: Decimal, symbol: String) -> String {
        let formatted = localizedMagnitude(amounts.compact(value))
        return symbol.isEmpty ? formatted : formatted + " " + symbol
    }

    public func plain(_ decimalString: String) -> String {
        guard !decimalString.isEmpty else { return "" }
        return amounts.exact(Self.decimal(from: decimalString))
    }

    public func leverage(_ value: Double) -> String {
        let scale = value == value.rounded() ? 0 : 1
        return amounts.exact(Self.rounded(Self.decimal(value), scale: scale)) + "⨯"
    }

    public func leverageBadge(_ value: Double) -> String {
        leverage(value).uppercased()
    }

    /// A leg reads as what was typed for it: its ROI, or its trigger price.
    public func autoCloseSummary(_ autoClose: PerpsAutoClose, typedROI: PerpsAutoCloseROIInput = .none) -> String? {
        func leg(_ trigger: PerpsAutoCloseTrigger, _ roi: PerpsAutoCloseROI?) -> String {
            roi?.value.map(signedPercent) ?? price(trigger.triggerPrice)
        }
        var parts: [String] = []
        if let takeProfit = autoClose.takeProfit { parts.append("\(leg(takeProfit, typedROI.takeProfit)) TP") }
        if let stopLoss = autoClose.stopLoss { parts.append("\(leg(stopLoss, typedROI.stopLoss)) SL") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Helpers

    private func amount(_ value: Decimal) -> String {
        localizedMagnitude(withCents(amounts.usdCompact(value)))
    }

    private func localizedMagnitude(_ formatted: String) -> String {
        let digits = String(formatted.dropLast())
        switch formatted.last {
        case "M": return TKLocales.Perps.Number.millions(digits)
        case "B": return TKLocales.Perps.Number.billions(digits)
        case "T": return TKLocales.Perps.Number.trillions(digits)
        default: return formatted
        }
    }

    private func roundedUsd(_ value: Decimal) -> String {
        amounts.usdCompact(Self.rounded(value, scale: 2))
    }

    private func withCents(_ formatted: String) -> String {
        guard let separator = locale.decimalSeparator,
              let range = formatted.range(of: separator, options: .backwards)
        else { return formatted }
        let fraction = formatted[range.upperBound...]
        return fraction.count == 1 && fraction.allSatisfy(\.isNumber) ? formatted + "0" : formatted
    }

    private static let signSpace = " "

    private static let candleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMM HH:mm")
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    private static func decimal(from string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private static func decimal(_ value: Double) -> Decimal {
        Decimal(string: value.description, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    private static func rounded(_ value: Decimal, scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, mode)
        return result
    }
}
