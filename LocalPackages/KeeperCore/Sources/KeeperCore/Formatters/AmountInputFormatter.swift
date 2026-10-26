import BigInt
import Foundation

@frozen public enum AmountInputFormatter {
    public static func normalizedString(
        _ string: String?,
        decimalSeparator: String = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? ".",
        maximumIntegerDigits: Int? = nil,
        maximumFractionDigits: Int? = nil,
        interpretsLeadingZeroAsFractionalShortcut: Bool = true
    ) -> String? {
        guard let string else { return nil }

        let decimalSeparator = decimalSeparator.isEmpty ? "." : decimalSeparator
        var integer = ""
        var fraction = ""
        var hasDecimalSeparator = false
        var hasDigits = false

        for character in string {
            if let digit = normalizedDigit(character) {
                hasDigits = true
                if hasDecimalSeparator {
                    if let maximumFractionDigits, fraction.count >= maximumFractionDigits {
                        continue
                    }
                    fraction += digit
                } else {
                    if let maximumIntegerDigits, integer.count >= maximumIntegerDigits {
                        continue
                    }
                    integer += digit
                }
            } else if isDecimalSeparator(character, localeDecimalSeparator: decimalSeparator) {
                guard maximumFractionDigits != 0 else { return nil }
                guard !hasDecimalSeparator else { return nil }
                hasDecimalSeparator = true
            } else if character.isWhitespace || isSpaceSeparator(character) {
                continue
            } else {
                return nil
            }
        }

        guard hasDigits || hasDecimalSeparator else {
            return ""
        }

        if integer.isEmpty {
            integer = "0"
        }

        if hasDecimalSeparator {
            return normalizedInteger(integer) + decimalSeparator + fraction
        } else if interpretsLeadingZeroAsFractionalShortcut,
                  maximumFractionDigits != 0,
                  integer.first == "0"
        {
            let fraction = String(integer.dropFirst())
            let limitedFraction = maximumFractionDigits.map {
                String(fraction.prefix($0))
            } ?? fraction
            return "0" + decimalSeparator + limitedFraction
        } else {
            return normalizedInteger(integer)
        }
    }

    public static func amount(
        from input: String,
        targetFractionalDigits: Int
    ) -> (amount: BigUInt, fraction: Int) {
        guard
            let normalized = normalizedString(
                input,
                decimalSeparator: ".",
                interpretsLeadingZeroAsFractionalShortcut: targetFractionalDigits > 0
            ),
            !normalized.isEmpty
        else {
            return (0, 0)
        }

        let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count <= 2 else { return (0, 0) }

        let integer = String(components[0])
        let fraction = components.count == 2 ? String(components[1]) : ""
        let truncatedFraction = fraction.count > targetFractionalDigits
            ? String(fraction.prefix(targetFractionalDigits))
            : fraction
        let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - truncatedFraction.count))
        let joined = integer + (components.count == 2 ? truncatedFraction : "") + zeroString

        return (BigUInt(joined) ?? 0, min(fraction.count, targetFractionalDigits))
    }

    private static func isDecimalSeparator(
        _ character: Character,
        localeDecimalSeparator: String
    ) -> Bool {
        character == "."
            || character == ","
            || character == "\u{066B}"
            || character == "\u{060C}"
            || String(character) == localeDecimalSeparator
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

    private static func isSpaceSeparator(_ character: Character) -> Bool {
        switch character {
        case "\u{00A0}", "\u{2007}", "\u{202F}", "\u{2009}":
            return true
        default:
            return false
        }
    }
}
