//
//  SimplifiedAmountFormatter.swift
//  KeeperCore
//
//  Simplified amount formatter with cleaner architecture
//

import BigInt
import Foundation

// MARK: - Public Types

public enum AmountDisplayStyle {
    case compact // Apply truncation rules for display (lists, summaries)
    case exactValue // Show all fraction digits (input fields, details)
}

public enum AmountSignPolicy {
    case negativeOnly // "-" for < 0, nothing for > 0 (default)
    case always // "+" for > 0, "-" for < 0
    case none // never show sign
}

public protocol CurrencyDisplayable {
    var symbol: String { get }
    var symbolOnLeft: Bool { get }
}

public enum AmountAccessoryType {
    case none
    case symbol(_ text: String, onLeft: Bool = false)
    case currency(CurrencyDisplayable)
}

// MARK: - Amount Formatter

/// A simplified amount formatter that supports both compact display rules and exact value formatting.
///
/// Compact rules (for display in lists/summaries):
/// - Zero: "0"
/// - >= 1000: Integer only (e.g., "1 234")
/// - 1-999: Up to 2 decimals (e.g., "15.45")
/// - 0-1: 3 significant digits (e.g., "0.000123")
///
/// Exact value: Shows all fraction digits with optional trailing zero trimming
public class AmountFormatter: Formatter {
    // MARK: - Configuration

    public struct Configuration {
        public var locale: Locale
        public var style: AmountDisplayStyle
        public var groupDigits: Bool
        public var trimTrailingZeros: Bool
        public var signPolicy: AmountSignPolicy
        public var space: String

        public init(
            locale: Locale = .current,
            style: AmountDisplayStyle = .compact,
            groupDigits: Bool = true,
            trimTrailingZeros: Bool = true,
            signPolicy: AmountSignPolicy = .none,
            space: String = "\u{2009}" // thin space
        ) {
            self.locale = locale
            self.style = style
            self.groupDigits = groupDigits
            self.trimTrailingZeros = trimTrailingZeros
            self.signPolicy = signPolicy
            self.space = space
        }
    }

    private let config: Configuration

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) {
        self.config = configuration
        super.init()
    }

    public required init?(coder: NSCoder) {
        self.config = Configuration()
        super.init(coder: coder)
    }

    // MARK: - Foundation Formatter Protocol

    override public func string(for obj: Any?) -> String? {
        if let amount = obj as? BigUInt {
            return format(amount: amount, fractionDigits: 9)
        }
        if let decimal = obj as? Decimal {
            return format(decimal: decimal)
        }
        if let number = obj as? NSNumber {
            return format(decimal: number.decimalValue)
        }
        return nil
    }

    // MARK: - Main Formatting Methods

    /// Format a BigUInt amount with specified fraction digits
    public func format(
        amount: BigUInt,
        fractionDigits: Int,
        accessory: AmountAccessoryType = .none,
        isNegative: Bool = false,
        style: AmountDisplayStyle? = nil
    ) -> String {
        let displayStyle = style ?? config.style

        // Split into integer and fraction parts
        let (integer, fraction) = splitAmount(amount: amount, fractionDigits: fractionDigits)

        // Apply formatting rules based on style
        let (finalInteger, finalFraction): (String, String?)
        if displayStyle == .compact {
            (finalInteger, finalFraction) = applyCompactRules(integer: integer, fraction: fraction)
        } else {
            finalFraction = config.trimTrailingZeros ? trimTrailingZeros(fraction) : (fraction.isEmpty ? nil : fraction)
            finalInteger = integer
        }

        // Build final string
        return buildFormattedString(
            integer: finalInteger,
            fraction: finalFraction,
            isNegative: isNegative,
            accessory: accessory
        )
    }

    /// Format a Decimal value
    public func format(
        decimal: Decimal,
        accessory: AmountAccessoryType = .none,
        style: AmountDisplayStyle? = nil
    ) -> String {
        let displayStyle = style ?? config.style
        let isNegative = decimal < 0
        let magnitude = isNegative ? -decimal : decimal

        // Convert decimal to string representation
        let formatter = NumberFormatter()
        formatter.locale = config.locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 80
        formatter.roundingMode = .down

        let numberString = formatter.string(from: magnitude as NSDecimalNumber) ?? "0"
        let decimalSeparator = formatter.decimalSeparator ?? "."

        // Split into integer and fraction
        let (integer, fraction): (String, String)
        if let separatorIndex = numberString.firstIndex(of: Character(decimalSeparator)) {
            integer = String(numberString[..<separatorIndex])
            fraction = String(numberString[numberString.index(after: separatorIndex)...])
        } else {
            integer = numberString
            fraction = ""
        }

        // Apply formatting rules based on style
        let (finalInteger, finalFraction): (String, String?)
        if displayStyle == .compact {
            (finalInteger, finalFraction) = applyCompactRules(integer: integer, fraction: fraction)
        } else {
            finalFraction = config.trimTrailingZeros ? trimTrailingZeros(fraction) : (fraction.isEmpty ? nil : fraction)
            finalInteger = integer
        }

        // Build final string
        return buildFormattedString(
            integer: finalInteger,
            fraction: finalFraction,
            isNegative: isNegative,
            accessory: accessory
        )
    }

    // MARK: - Private Methods

    /// Split BigUInt into integer and fraction string parts
    private func splitAmount(amount: BigUInt, fractionDigits: Int) -> (integer: String, fraction: String) {
        let scale = max(0, fractionDigits)
        let amountString = amount.description

        guard scale > 0 else {
            return (amountString.isEmpty ? "0" : amountString, "")
        }

        // Pad with leading zeros if needed
        let needsPadding = amountString.count <= scale
        let padded = needsPadding
            ? String(repeating: "0", count: scale - amountString.count + 1) + amountString
            : amountString

        let splitIndex = padded.index(padded.endIndex, offsetBy: -scale)
        let integerPart = String(padded[..<splitIndex])
        let fractionPart = String(padded[splitIndex...])

        return (integerPart.isEmpty ? "0" : integerPart, fractionPart)
    }

    /// Apply compact display rules (truncation for lists/summaries)
    private func applyCompactRules(integer: String, fraction: String) -> (integer: String, fraction: String?) {
        // Rule 1: Zero
        if integer == "0", (fraction.isEmpty || fraction.allSatisfy { $0 == "0" }) {
            return ("0", nil)
        }

        // Rule 2: >= 1000 (4+ digit integer) - Drop fraction
        if integer.count >= 4 {
            return (integer, nil)
        }

        // Rule 3: 1 to 999 (1-3 digit integer) - Max 2 decimals
        if integer != "0", integer.count <= 3, !fraction.isEmpty {
            let truncated = String(fraction.prefix(2))
            let trimmed = trimTrailingZeros(truncated)
            return (integer, trimmed.isEmpty ? nil : trimmed)
        }

        if integer != "0", integer.count <= 3 {
            return (integer, nil)
        }

        // Rule 4: 0 to 1 (integer is "0") - 3 significant digits
        if integer == "0", !fraction.isEmpty {
            guard let firstNonZeroIndex = fraction.firstIndex(where: { $0 != "0" }) else {
                return ("0", nil)
            }

            let leadingZeroCount = fraction.distance(from: fraction.startIndex, to: firstNonZeroIndex)
            let afterZeros = fraction[firstNonZeroIndex...]
            let significantPart = String(afterZeros.prefix(3))
            let trimmed = trimTrailingZeros(significantPart)

            if trimmed.isEmpty {
                return ("0", nil)
            }

            let result = String(repeating: "0", count: leadingZeroCount) + trimmed
            return ("0", result)
        }

        return (integer, nil)
    }

    /// Trim trailing zeros from a string
    private func trimTrailingZeros(_ string: String) -> String {
        var result = string
        while result.last == "0" {
            result.removeLast()
        }
        return result
    }

    /// Apply digit grouping (thousands separator)
    private func applyGrouping(_ integer: String) -> String {
        guard config.groupDigits && integer.count > 3 else { return integer }

        let groupingSeparator = config.locale.groupingSeparator ?? " "
        var parts: [Substring] = []
        var index = integer.endIndex

        while index > integer.startIndex {
            let start = integer.index(index, offsetBy: -3, limitedBy: integer.startIndex) ?? integer.startIndex
            parts.append(integer[start ..< index])
            index = start
        }

        return parts.reversed().joined(separator: groupingSeparator)
    }

    /// Build the final formatted string with sign, grouping, and accessory
    private func buildFormattedString(
        integer: String,
        fraction: String?,
        isNegative: Bool,
        accessory: AmountAccessoryType
    ) -> String {
        let decimalSeparator = config.locale.decimalSeparator ?? "."
        let groupedInteger = applyGrouping(integer)

        // Build number string
        var numberString: String
        if let fraction = fraction, !fraction.isEmpty {
            numberString = groupedInteger + decimalSeparator + fraction
        } else {
            numberString = groupedInteger
        }

        // Apply sign policy (never show sign for zero)
        if numberString != "0" {
            switch config.signPolicy {
            case .negativeOnly:
                if isNegative {
                    numberString = String.Symbol.minus + config.space + numberString
                }
            case .always:
                numberString = (isNegative ? String.Symbol.minus : String.Symbol.plus) + config.space + numberString
            case .none:
                break
            }
        }

        // Apply accessory (symbol or currency)
        switch accessory {
        case .none:
            return numberString
        case let .symbol(text, onLeft):
            return onLeft
                ? text + config.space + numberString
                : numberString + config.space + text
        case let .currency(currency):
            return currency.symbolOnLeft
                ? currency.symbol + config.space + numberString
                : numberString + config.space + currency.symbol
        }
    }
}
