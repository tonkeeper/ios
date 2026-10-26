import Foundation
import PerpsModels
import TKLocalize

public struct PerpsFormatting {
    private let amounts: any PerpsAmountFormatting

    public init(amounts: any PerpsAmountFormatting) {
        self.amounts = amounts
    }

    public func usd(_ value: Double) -> String {
        amounts.usdCompact(Self.decimal(value))
    }

    public func usd(_ decimalString: String) -> String {
        amounts.usdCompact(Self.decimal(from: decimalString))
    }

    public func signedUsd(_ value: Double) -> String {
        let magnitude = amounts.usdCompact(abs(Self.decimal(value)))
        if value > 0 { return String.Symbol.plus + Self.signSpace + magnitude }
        if value < 0 { return String.Symbol.minus + Self.signSpace + magnitude }
        return magnitude
    }

    public func signedPercent(_ value: Double) -> String {
        amounts.signedPercent(Self.decimal(value))
    }

    public func funding(percent value: Double) -> String {
        let formatted = amounts.fundingExact(Self.rounded(Self.decimal(value), scale: 8))
        return formatted + String.Symbol.shortSpace + "%"
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
        let formatted = amounts.compact(value)
        return symbol.isEmpty ? formatted : formatted + " " + symbol
    }

    public func plain(_ decimalString: String) -> String {
        guard !decimalString.isEmpty else { return "" }
        return amounts.exact(Self.decimal(from: decimalString))
    }

    public func leverage(_ value: Double) -> String {
        let scale = value == value.rounded() ? 0 : 1
        return amounts.exact(Self.rounded(Self.decimal(value), scale: scale)) + "x"
    }

    public func leverageBadge(_ value: Double) -> String {
        leverage(value).uppercased()
    }

    /// A leg reads as what was typed for it: its ROI, or its trigger price.
    public func autoCloseSummary(_ autoClose: PerpsAutoClose, typedROI: PerpsAutoCloseROIInput = .none) -> String? {
        func leg(_ trigger: PerpsAutoCloseTrigger, _ roi: PerpsAutoCloseROI?) -> String {
            roi?.value.map(signedPercent) ?? usd(trigger.triggerPrice)
        }
        var parts: [String] = []
        if let takeProfit = autoClose.takeProfit { parts.append("\(leg(takeProfit, typedROI.takeProfit)) TP") }
        if let stopLoss = autoClose.stopLoss { parts.append("\(leg(stopLoss, typedROI.stopLoss)) SL") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Helpers

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

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }
}
