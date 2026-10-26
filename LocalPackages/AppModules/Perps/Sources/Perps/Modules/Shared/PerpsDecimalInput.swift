import Foundation

public enum PerpsDecimalInput {
    public static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: ".")
    }

    public static func double(_ text: String) -> Double? {
        let posix = normalized(text).trimmingCharacters(in: .whitespaces)
        guard !posix.isEmpty,
              let value = Decimal(string: posix, locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    public static func sanitize(_ text: String, decimals: Int) -> String {
        let digitsAndSeparators = text.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        let parts = digitsAndSeparators.split(separator: ".", omittingEmptySubsequences: false)
        let oneSeparator = parts.count > 1 ? parts[0] + "." + parts[1...].joined() : digitsAndSeparators
        return normalizedString(oneSeparator, maximumFractionDigits: clamped(decimals)) ?? oneSeparator
    }

    public static func text(_ value: Double, decimals: Int) -> String {
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

    public static func usdText(_ value: Double) -> String {
        let posix = Locale(identifier: "en_US_POSIX")
        var exact = Decimal(string: text(value, decimals: 8), locale: posix) ?? 0
        var cents = Decimal()
        NSDecimalRound(&cents, &exact, 2, .down)
        return NSDecimalNumber(decimal: cents).description(withLocale: posix)
    }

    public static func percentText(_ value: Double) -> String {
        text(value, decimals: 2)
    }

    private static func clamped(_ decimals: Int) -> Int {
        max(0, min(decimals, 8))
    }

    private static func normalizedString(_ string: String, maximumFractionDigits: Int) -> String? {
        var integer = ""
        var fraction = ""
        var hasDecimalSeparator = false
        var hasDigits = false

        for character in string {
            if let digit = normalizedDigit(character) {
                hasDigits = true
                if hasDecimalSeparator {
                    guard fraction.count < maximumFractionDigits else { continue }
                    fraction += digit
                } else {
                    integer += digit
                }
            } else if character == "." {
                guard maximumFractionDigits != 0, !hasDecimalSeparator else { return nil }
                hasDecimalSeparator = true
            } else {
                return nil
            }
        }

        guard hasDigits || hasDecimalSeparator else { return "" }
        if integer.isEmpty { integer = "0" }
        let normalizedInteger = normalizedInteger(integer)
        return hasDecimalSeparator ? normalizedInteger + "." + fraction : normalizedInteger
    }

    private static func normalizedDigit(_ character: Character) -> String? {
        guard
            character.unicodeScalars.count == 1,
            let scalar = character.unicodeScalars.first,
            scalar.properties.numericType == .decimal,
            let numericValue = scalar.properties.numericValue
        else {
            return nil
        }

        let digit = Int(numericValue)
        guard digit >= 0, digit <= 9 else { return nil }
        return String(digit)
    }

    private static func normalizedInteger(_ integer: String) -> String {
        let trimmed = integer.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? "0" : String(trimmed)
    }
}
