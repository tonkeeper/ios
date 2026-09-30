import Foundation
import KeeperCore

enum PerpsDecimalInput {
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: ".")
    }

    static func double(_ text: String) -> Double? {
        let posix = normalized(text).trimmingCharacters(in: .whitespaces)
        guard !posix.isEmpty,
              let value = Decimal(string: posix, locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    static func sanitize(_ text: String, decimals: Int) -> String {
        let digitsAndSeparators = text.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        let parts = digitsAndSeparators.split(separator: ".", omittingEmptySubsequences: false)
        let oneSeparator = parts.count > 1 ? parts[0] + "." + parts[1...].joined() : digitsAndSeparators
        return AmountInputFormatter.normalizedString(
            oneSeparator,
            decimalSeparator: ".",
            maximumFractionDigits: clamped(decimals),
            interpretsLeadingZeroAsFractionalShortcut: false
        ) ?? oneSeparator
    }

    static func text(_ value: Double, decimals: Int) -> String {
        let formatted = String(
            format: "%.\(clamped(decimals))f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
        guard formatted.contains(".") else { return formatted }
        var trimmed = formatted
        while trimmed.hasSuffix("0") {
            trimmed.removeLast()
        }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    static func usdText(_ value: Double) -> String {
        text(value, decimals: 2)
    }

    static func percentText(_ value: Double) -> String {
        text(value, decimals: 2)
    }

    private static func clamped(_ decimals: Int) -> Int {
        max(0, min(decimals, 8))
    }
}
