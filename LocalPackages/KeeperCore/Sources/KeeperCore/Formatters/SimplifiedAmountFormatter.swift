//
//  SimplifiedAmountFormatter.swift
//  KeeperCore
//
//  Simplified amount formatter with cleaner architecture
//

import BigInt
import ChainKit
import Foundation
import TKLocalize

// MARK: - Public Types

public enum AmountDisplayStyle {
    case regular // Show up to 8 fraction digits for values >= 1
    case compact // Show compact display rules for short UI
    case fiatBalance // Show fiat balances with 2 fraction digits
    case exactValue // Show all fraction digits (input fields, details)
    case percent // Show percentage values with up to 2 fraction digits and percent sign
}

public enum AmountSignPolicy {
    case negativeOnly // "−" for < 0, nothing for > 0 (default)
    case always // "+" for > 0, "−" for < 0
    case none // never show sign
}

public enum CurrencyDisplayType {
    case fiat
    case token
}

public protocol CurrencyDisplayable {
    var symbol: String { get }
    var symbolOnLeft: Bool { get }
    var currencyDisplayType: CurrencyDisplayType { get }
}

struct AmountCurrency: CurrencyDisplayable {
    let symbol: String
    let symbolOnLeft: Bool
    let currencyDisplayType: CurrencyDisplayType

    init(
        symbol: String,
        symbolOnLeft: Bool = false,
        currencyDisplayType: CurrencyDisplayType
    ) {
        self.symbol = symbol
        self.symbolOnLeft = symbolOnLeft
        self.currencyDisplayType = currencyDisplayType
    }
}

public enum AmountAccessoryType {
    case none
    case token(CurrencyDisplayable)
    case fiat(CurrencyDisplayable)

    public static func tokenSymbol(_ text: String, onLeft: Bool = false) -> AmountAccessoryType {
        .token(
            AmountCurrency(
                symbol: text,
                symbolOnLeft: onLeft,
                currencyDisplayType: .token
            )
        )
    }

    public init(currency: CurrencyDisplayable) {
        switch currency.currencyDisplayType {
        case .fiat:
            self = .fiat(currency)
        case .token:
            self = .token(currency)
        }
    }
}

public struct BalanceHeaderAmountFormat: Hashable {
    public struct NumberPart: Hashable {
        public enum Role: Hashable {
            case primary
            case fraction
        }

        public let text: String
        public let role: Role

        public init(text: String, role: Role) {
            self.text = text
            self.role = role
        }
    }

    public enum TextSize: Hashable {
        case regular
        case reduced
    }

    public let leadingAccessory: String?
    public let trailingAccessory: String?
    public let numberParts: [NumberPart]
    public let fullText: String
    public let tooltipText: String?
    public let textSize: TextSize

    public init(
        leadingAccessory: String? = nil,
        trailingAccessory: String? = nil,
        numberParts: [NumberPart],
        fullText: String,
        tooltipText: String? = nil,
        textSize: TextSize
    ) {
        self.leadingAccessory = leadingAccessory
        self.trailingAccessory = trailingAccessory
        self.numberParts = numberParts
        self.fullText = fullText
        self.tooltipText = tooltipText
        self.textSize = textSize
    }
}

// MARK: - Amount Formatter

/// A simplified amount formatter that supports compact, balance, and exact value formatting.
///
/// Regular rules:
/// - Zero: "0"
/// - Values lower than 1: Up to 3 significant fraction digits after leading zeros
/// - Values greater than or equal to 1: Up to 8 fraction digits
///
/// Compact rules:
/// - Values lower than 1: Up to 3 significant fraction digits after leading zeros, but no more than
///   8 fraction digits total; non-zero values below 0.00000001 display as "< 0.00000001"
/// - Values greater than or equal to 1: Up to 2 fraction digits
///
/// Fiat balance rules:
/// - Uses 2 decimals for fiat currencies and 8 decimals for token currencies
/// - Positive values smaller than the display precision: "< 0.01" or "< 0.00000001"
///
/// Exact value: Shows all fraction digits with optional trailing zero trimming.
/// `Foundation.` is explicit throughout this file: importing ChainKit brings its own
/// `Formatter` and `Decimal` into scope.
public class AmountFormatter: Foundation.Formatter {
    private enum Constants {
        static let compactMaxSignificantFractionDigits = 3
        static let compactMinimumFractionDigits = 8
        static let fiatFractionDigits = 2
        static let fiatBalanceTokenFractionDigits = 8
        static let percentFractionDigits = 2
        static let groupingSeparator = " "
        static let balanceReducedTextMinimum = "1000000"
        static let balanceCompactMinimum = "10000000"
        static let balanceCompactFractionDigits = 1
        static let balanceCompactSuffixes = ["", "K", "M", "B", "T", "Q"]
    }

    private struct FormattedNumberParts {
        let integer: String
        let fraction: String?
        let isLessThanMinimum: Bool
        let isZero: Bool
    }

    // MARK: - Configuration

    public struct Configuration {
        public static var defaultLocale: Locale {
            makeLocale(
                preferredLocalizations: Bundle.main.preferredLocalizations,
                developmentLocalization: Bundle.main.developmentLocalization,
                fallback: .current
            )
        }

        static func makeLocale(
            preferredLocalizations: [String],
            developmentLocalization: String?,
            fallback: Locale
        ) -> Locale {
            let identifier = preferredLocalizations.first {
                !$0.isEmpty && $0 != "Base"
            } ?? developmentLocalization

            guard let identifier, !identifier.isEmpty else {
                return fallback
            }

            return Locale(identifier: identifier)
        }

        public var locale: Locale
        public var style: AmountDisplayStyle
        public var groupDigits: Bool
        public var trimTrailingZeros: Bool
        public var signPolicy: AmountSignPolicy
        public var space: String

        public init(
            locale: Locale = AmountFormatter.Configuration.defaultLocale,
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

    public let config: Configuration

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
        if let decimal = obj as? Foundation.Decimal {
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
        let (integer, fraction) = splitAmount(amount: amount, fractionDigits: fractionDigits)

        return formatted(
            integer: integer,
            fraction: fraction,
            isNegative: isNegative,
            accessory: accessory,
            style: style ?? config.style
        )
    }

    /// Format a Decimal value
    public func format(
        decimal: Foundation.Decimal,
        accessory: AmountAccessoryType = .none,
        style: AmountDisplayStyle? = nil
    ) -> String {
        guard !decimal.isNaN else { return "—" }

        let displayStyle = style ?? config.style
        let isNegative = decimal < 0
        let magnitude = isNegative ? -decimal : decimal
        let (integer, fraction) = splitAmount(decimal: magnitude)

        return formatted(
            integer: integer,
            fraction: fraction,
            isNegative: isNegative,
            accessory: accessory,
            style: displayStyle
        )
    }

    /// `.compact`, `.exactValue` and `.fiatBalance` are ChainKit's; `.regular` and `.percent` still
    /// run the local rules — the first needs the rounding/8-digit-cap switch, the second a
    /// "below 0.01 → 0" knob ChainKit has no parameter for.
    private func formatted(
        integer: String,
        fraction: String,
        isNegative: Bool,
        accessory: AmountAccessoryType,
        style: AmountDisplayStyle
    ) -> String {
        let parts: FormattedNumberParts
        switch style {
        case .compact, .exactValue, .fiatBalance:
            return chainKitFormatted(
                integer: integer,
                fraction: fraction,
                isNegative: isNegative,
                accessory: accessory,
                style: style
            )
        case .regular:
            parts = applyRegularRules(integer: integer, fraction: fraction)
        case .percent:
            parts = applyPercentRules(integer: integer, fraction: fraction)
        }

        return buildFormattedString(
            integer: parts.integer,
            fraction: parts.fraction,
            isNegative: isNegative,
            accessory: accessory,
            isLessThanMinimum: parts.isLessThanMinimum,
            isZero: parts.isZero,
            isPercent: style == .percent
        )
    }

    public func formatInput(
        amount: BigUInt,
        fractionDigits: Int
    ) -> String {
        var configuration = config
        configuration.groupDigits = false
        return AmountFormatter(configuration: configuration).format(
            amount: amount,
            fractionDigits: fractionDigits,
            style: .exactValue
        )
    }

    public func formatBalanceHeaderAmount(
        decimal: Foundation.Decimal,
        accessory: AmountAccessoryType = .none
    ) -> BalanceHeaderAmountFormat {
        guard !decimal.isNaN else {
            return BalanceHeaderAmountFormat(
                numberParts: [.init(text: "—", role: .primary)],
                fullText: "—",
                textSize: .regular
            )
        }

        let isNegative = decimal < 0
        let magnitude = isNegative ? -decimal : decimal
        let (integer, fraction) = splitAmount(decimal: magnitude)
        return formatBalanceHeaderAmount(
            integer: integer,
            fraction: fraction,
            accessory: accessory,
            isNegative: isNegative
        )
    }

    // MARK: - ChainKit

    private func chainKitSpec(
        for style: AmountDisplayStyle,
        accessory: AmountAccessoryType,
        fractionDigits: Int
    ) -> any ScaleSpec {
        switch style {
        case .compact:
            ScaleSpecCompact.shared
        case .exactValue:
            if config.trimTrailingZeros {
                ScaleSpecExact.shared
            } else {
                // BigDecimal normalizes trailing zeros, so retain the input scale explicitly.
                ScaleSpecFixed(scale: Int32(fractionDigits), rounding: .towardsZero)
            }
        case .fiatBalance:
            ScaleSpecFixed(
                scale: Int32(fiatBalanceFractionDigits(for: accessory)),
                rounding: .towardsZero
            )
        case .regular, .percent:
            preconditionFailure("\(style) is formatted locally, not by ChainKit")
        }
    }

    /// ChainKit reads no locale of its own — every glyph it prints comes from here.
    ///
    /// `symbolSpacing` has to be per call: iOS picks the space from the symbol's glyphs
    /// (`space(for:)` — "TON" gets U+0020, "$" and "R$" get U+2009), ChainKit would pick it from
    /// the symbol's role, which disagrees on exactly those cases.
    private func chainKitOptions(
        symbol: String,
        placement: SymbolPlacement
    ) -> FormatOptions {
        FormatOptions(
            decimalSeparator: config.locale.decimalSeparator ?? ".",
            groupingSeparator: config.groupDigits ? Constants.groupingSeparator : nil,
            minusSign: String.Symbol.minus,
            plusSign: String.Symbol.plus,
            signSpacing: config.space,
            lessThanPrefix: "< ",
            approximatePrefix: String.Symbol.almostEqual + " ",
            approximateAppliesToFiatPart: false,
            symbolPlacement: placement,
            currencyPlacement: placement,
            symbolSpacing: symbol.isEmpty ? nil : space(for: symbol),
            symbolOverride: nil,
            percentSpacing: config.space
        )
    }

    private func chainKitFormatted(
        integer: String,
        fraction: String,
        isNegative: Bool,
        accessory: AmountAccessoryType,
        style: AmountDisplayStyle
    ) -> String {
        let magnitude = fraction.isEmpty ? integer : "\(integer).\(fraction)"
        assert(
            magnitude.allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") },
            "ChainKit parses ASCII digits only, got \(magnitude)"
        )
        let value = BignumBigDecimal.companion.parseString(
            string: isNegative ? "-" + magnitude : magnitude,
            base: 10
        )

        let symbol: String
        let placement: SymbolPlacement
        switch accessory {
        case .none:
            symbol = ""
            placement = .leading
        case let .token(currency),
             let .fiat(currency):
            symbol = currency.symbol
            placement = currency.symbolOnLeft ? .leading : .trailing
        }

        return ChainKit.Formatter.shared.formatFiat(
            value: value,
            currency: FiatCurrency(symbol: symbol),
            sign: config.signPolicy.chainKitSignMode,
            approximate: false,
            spec: chainKitSpec(for: style, accessory: accessory, fractionDigits: fraction.count),
            isShorten: style == .compact,
            trimTrailingZeros: style == .fiatBalance ? false : config.trimTrailingZeros,
            options: chainKitOptions(symbol: symbol, placement: placement)
        )
    }

    // MARK: - Private Methods

    private func formatBalanceHeaderAmount(
        integer: String,
        fraction: String,
        accessory: AmountAccessoryType,
        isNegative: Bool
    ) -> BalanceHeaderAmountFormat {
        let fiatBalanceParts = applyFiatBalanceRules(
            integer: integer,
            fraction: fraction,
            fractionDigits: fiatBalanceFractionDigits(for: accessory)
        )
        let fullText = buildFormattedString(
            integer: fiatBalanceParts.integer,
            fraction: fiatBalanceParts.fraction,
            isNegative: isNegative,
            accessory: accessory,
            isLessThanMinimum: fiatBalanceParts.isLessThanMinimum,
            isZero: fiatBalanceParts.isZero
        )

        if isAtLeast(integer: integer, threshold: Constants.balanceCompactMinimum) {
            let accessory = balanceAccessory(for: accessory)
            return BalanceHeaderAmountFormat(
                leadingAccessory: accessory.leading,
                trailingAccessory: accessory.trailing,
                numberParts: compactBalanceNumberParts(
                    integer: integer,
                    fraction: fraction,
                    isNegative: isNegative
                ),
                fullText: fullText,
                tooltipText: fullText,
                textSize: .regular
            )
        }

        if fiatBalanceParts.isLessThanMinimum {
            return BalanceHeaderAmountFormat(
                numberParts: splitNumberText(fullText),
                fullText: fullText,
                textSize: .regular
            )
        }

        let accessory = balanceAccessory(for: accessory)
        return BalanceHeaderAmountFormat(
            leadingAccessory: accessory.leading,
            trailingAccessory: accessory.trailing,
            numberParts: balanceNumberParts(
                integer: fiatBalanceParts.integer,
                fraction: fiatBalanceParts.fraction,
                isNegative: isNegative,
                isLessThanMinimum: false,
                isZero: fiatBalanceParts.isZero
            ),
            fullText: fullText,
            textSize: isAtLeast(integer: integer, threshold: Constants.balanceReducedTextMinimum) ? .reduced : .regular
        )
    }

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

    /// Preserve Decimal precision and ASCII digits; apply the display locale only when rendering.
    private func splitAmount(decimal: Foundation.Decimal) -> (integer: String, fraction: String) {
        var decimal = decimal
        let numberString = NSDecimalString(&decimal, Locale(identifier: "en_US_POSIX"))

        if let separatorIndex = numberString.firstIndex(of: ".") {
            return (
                String(numberString[..<separatorIndex]),
                String(numberString[numberString.index(after: separatorIndex)...])
            )
        } else {
            return (numberString, "")
        }
    }

    /// Apply regular token-like display rules
    private func applyRegularRules(integer: String, fraction: String) -> FormattedNumberParts {
        applyTokenLikeRules(
            integer: integer,
            fraction: fraction,
            maxGreaterThanOneFractionDigits: Constants.compactMinimumFractionDigits
        )
    }

    private func applyTokenLikeRules(
        integer: String,
        fraction: String,
        maxGreaterThanOneFractionDigits: Int,
        smallValueMaxFractionDigits: Int? = nil
    ) -> FormattedNumberParts {
        guard !isZero(integer: integer, fraction: fraction) else {
            return FormattedNumberParts(integer: "0", fraction: nil, isLessThanMinimum: false, isZero: true)
        }

        if integer == "0" {
            return applyCompactLessThanOneRules(
                fraction: fraction,
                maxFractionDigits: smallValueMaxFractionDigits
            )
        }

        let (truncatedInteger, truncatedFraction) = truncatedParts(
            integer: integer,
            fraction: fraction,
            maxFractionDigits: maxGreaterThanOneFractionDigits
        )

        return FormattedNumberParts(
            integer: truncatedInteger,
            fraction: truncatedFraction,
            isLessThanMinimum: false,
            isZero: false
        )
    }

    private func applyCompactLessThanOneRules(
        fraction: String,
        maxFractionDigits: Int? = nil
    ) -> FormattedNumberParts {
        guard let firstSignificantIndex = fraction.firstIndex(where: { $0 != "0" }) else {
            return FormattedNumberParts(integer: "0", fraction: nil, isLessThanMinimum: false, isZero: true)
        }

        let firstSignificantOffset = fraction.distance(from: fraction.startIndex, to: firstSignificantIndex)

        if let maxFractionDigits, firstSignificantOffset >= maxFractionDigits {
            return FormattedNumberParts(
                integer: "0",
                fraction: minimumFraction(digits: maxFractionDigits),
                isLessThanMinimum: true,
                isZero: false
            )
        }

        var maximumEndOffset = firstSignificantOffset + Constants.compactMaxSignificantFractionDigits
        if let maxFractionDigits {
            maximumEndOffset = min(maximumEndOffset, maxFractionDigits)
        }
        let endIndex = fraction.index(
            fraction.startIndex,
            offsetBy: min(maximumEndOffset, fraction.count)
        )
        let trimmed = trimTrailingZeros(String(fraction[..<endIndex]))
        return FormattedNumberParts(
            integer: "0",
            fraction: trimmed.isEmpty ? nil : trimmed,
            isLessThanMinimum: false,
            isZero: false
        )
    }

    /// Apply fiat balance display rules
    private func applyFiatBalanceRules(
        integer: String,
        fraction: String,
        fractionDigits: Int
    ) -> FormattedNumberParts {
        guard !isZero(integer: integer, fraction: fraction) else {
            return FormattedNumberParts(
                integer: "0",
                fraction: String(repeating: "0", count: fractionDigits),
                isLessThanMinimum: false,
                isZero: true
            )
        }

        let roundedDownFraction = paddedFraction(fraction, digits: fractionDigits)

        if integer == "0", roundedDownFraction.allSatisfy({ $0 == "0" }) {
            return FormattedNumberParts(
                integer: "0",
                fraction: minimumFraction(digits: fractionDigits),
                isLessThanMinimum: true,
                isZero: false
            )
        }

        return FormattedNumberParts(
            integer: integer,
            fraction: roundedDownFraction,
            isLessThanMinimum: false,
            isZero: false
        )
    }

    private func fiatBalanceFractionDigits(for accessory: AmountAccessoryType) -> Int {
        switch accessory {
        case .none:
            return Constants.fiatFractionDigits
        case let .token(displayable),
             let .fiat(displayable):
            switch displayable.currencyDisplayType {
            case .fiat:
                return Constants.fiatFractionDigits
            case .token:
                return Constants.fiatBalanceTokenFractionDigits
            }
        }
    }

    private func isAtLeast(integer: String, threshold: String) -> Bool {
        let integer = normalizedInteger(integer)
        if integer.count != threshold.count {
            return integer.count > threshold.count
        }
        return integer >= threshold
    }

    private func normalizedInteger(_ integer: String) -> String {
        let trimmed = integer.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? "0" : String(trimmed)
    }

    private func balanceAccessory(for accessory: AmountAccessoryType) -> (leading: String?, trailing: String?) {
        switch accessory {
        case .none:
            return (nil, nil)
        case let .token(currency),
             let .fiat(currency):
            return currency.symbolOnLeft
                ? (currency.symbol, nil)
                : (nil, currency.symbol)
        }
    }

    private func balanceNumberParts(
        integer: String,
        fraction: String?,
        isNegative: Bool,
        isLessThanMinimum: Bool,
        isZero: Bool
    ) -> [BalanceHeaderAmountFormat.NumberPart] {
        var primary = ""
        let signPrefix = signPrefix(isNegative: isNegative, isZero: isZero)
        if isLessThanMinimum {
            primary += (signPrefix ?? "") + "< "
        } else if let signPrefix {
            primary += signPrefix
        }

        primary += applyGrouping(integer)

        var parts = [
            BalanceHeaderAmountFormat.NumberPart(text: primary, role: .primary),
        ]

        if let fraction, !fraction.isEmpty {
            parts.append(
                BalanceHeaderAmountFormat.NumberPart(
                    text: (config.locale.decimalSeparator ?? ".") + fraction,
                    role: .fraction
                )
            )
        }

        return parts
    }

    private func compactBalanceNumberParts(
        integer: String,
        fraction: String,
        isNegative: Bool
    ) -> [BalanceHeaderAmountFormat.NumberPart] {
        let integer = normalizedInteger(integer)
        let groupIndex = min(
            (integer.count - 1) / 3,
            Constants.balanceCompactSuffixes.count - 1
        )
        let suffix = Constants.balanceCompactSuffixes[groupIndex]
        let suffixPower = groupIndex * 3
        let wholeDigitCount = max(1, integer.count - suffixPower)
        let wholeEndIndex = integer.index(integer.startIndex, offsetBy: wholeDigitCount)
        let whole = String(integer[..<wholeEndIndex])
        let compactFractionSource = String(integer[wholeEndIndex...]) + fraction
        let compactFraction = String(compactFractionSource.prefix(Constants.balanceCompactFractionDigits))
            .trimmingCharacters(in: CharacterSet(charactersIn: "0"))

        var primary = (signPrefix(isNegative: isNegative, isZero: false) ?? "") + whole

        if !compactFraction.isEmpty {
            primary += (config.locale.decimalSeparator ?? ".") + compactFraction
        }

        if !suffix.isEmpty {
            primary += suffix
        }

        return [BalanceHeaderAmountFormat.NumberPart(text: primary, role: .primary)]
    }

    private func splitNumberText(_ text: String) -> [BalanceHeaderAmountFormat.NumberPart] {
        let decimalSeparator = Character(config.locale.decimalSeparator ?? ".")
        guard let separatorIndex = text.firstIndex(of: decimalSeparator) else {
            return [BalanceHeaderAmountFormat.NumberPart(text: text, role: .primary)]
        }

        return [
            BalanceHeaderAmountFormat.NumberPart(
                text: String(text[..<separatorIndex]),
                role: .primary
            ),
            BalanceHeaderAmountFormat.NumberPart(
                text: String(text[separatorIndex...]),
                role: .fraction
            ),
        ]
    }

    private func signPrefix(isNegative: Bool, isZero: Bool) -> String? {
        guard !isZero else { return nil }
        switch config.signPolicy {
        case .negativeOnly:
            return isNegative ? String.Symbol.minus + config.space : nil
        case .always:
            return (isNegative ? String.Symbol.minus : String.Symbol.plus) + config.space
        case .none:
            return nil
        }
    }

    /// Apply percentage display rules
    private func applyPercentRules(integer: String, fraction: String) -> FormattedNumberParts {
        guard !isZero(integer: integer, fraction: fraction) else {
            return FormattedNumberParts(integer: "0", fraction: nil, isLessThanMinimum: false, isZero: true)
        }

        if integer == "0", isLessThanPercentMinimum(fraction) {
            return FormattedNumberParts(integer: "0", fraction: nil, isLessThanMinimum: false, isZero: true)
        }

        let (roundedInteger, roundedFraction) = roundedParts(
            integer: integer,
            fraction: fraction,
            maxFractionDigits: Constants.percentFractionDigits
        )

        return FormattedNumberParts(
            integer: roundedInteger,
            fraction: roundedFraction,
            isLessThanMinimum: false,
            isZero: false
        )
    }

    private func isLessThanPercentMinimum(_ fraction: String) -> Bool {
        paddedFraction(fraction, digits: Constants.percentFractionDigits).allSatisfy { $0 == "0" }
    }

    /// Trim trailing zeros from a string
    private func trimTrailingZeros(_ string: String) -> String {
        var result = string
        while result.last == "0" {
            result.removeLast()
        }
        return result
    }

    private func roundedParts(
        integer: String,
        fraction: String,
        maxFractionDigits: Int
    ) -> (integer: String, fraction: String?) {
        let fractionEndIndex = fraction.index(
            fraction.startIndex,
            offsetBy: min(maxFractionDigits, fraction.count)
        )
        let digits = String(fraction[..<fractionEndIndex])
        let shouldRound = fractionEndIndex < fraction.endIndex && shouldRoundUp(fraction[fractionEndIndex])
        let rounded = roundedDecimalDigits(digits, shouldRound: shouldRound)

        if rounded.overflow {
            return (incrementInteger(integer), nil)
        }

        let trimmed = trimTrailingZeros(rounded.digits)
        return (integer, trimmed.isEmpty ? nil : trimmed)
    }

    private func truncatedParts(
        integer: String,
        fraction: String,
        maxFractionDigits: Int
    ) -> (integer: String, fraction: String?) {
        let fractionEndIndex = fraction.index(
            fraction.startIndex,
            offsetBy: min(maxFractionDigits, fraction.count)
        )
        let trimmed = trimTrailingZeros(String(fraction[..<fractionEndIndex]))
        return (integer, trimmed.isEmpty ? nil : trimmed)
    }

    private func roundedDecimalDigits(
        _ digits: String,
        shouldRound: Bool
    ) -> (digits: String, overflow: Bool) {
        guard shouldRound else {
            return (digits, false)
        }
        guard !digits.isEmpty else {
            return ("", true)
        }

        var rounded = Array(digits)
        var index = rounded.index(before: rounded.endIndex)

        while true {
            if rounded[index] == "9" {
                rounded[index] = "0"
                if index == rounded.startIndex {
                    return ("1" + String(rounded), true)
                }
                index = rounded.index(before: index)
            } else {
                rounded[index] = incrementDigit(rounded[index])
                return (String(rounded), false)
            }
        }
    }

    private func shouldRoundUp(_ digit: Character) -> Bool {
        switch digit {
        case "5", "6", "7", "8", "9":
            return true
        default:
            return false
        }
    }

    private func incrementDigit(_ digit: Character) -> Character {
        switch digit {
        case "0": return "1"
        case "1": return "2"
        case "2": return "3"
        case "3": return "4"
        case "4": return "5"
        case "5": return "6"
        case "6": return "7"
        case "7": return "8"
        case "8": return "9"
        default: return digit
        }
    }

    private func incrementInteger(_ integer: String) -> String {
        var digits = Array(integer)
        var index = digits.index(before: digits.endIndex)

        while true {
            if digits[index] == "9" {
                digits[index] = "0"
                if index == digits.startIndex {
                    return "1" + String(digits)
                }
                index = digits.index(before: index)
            } else {
                digits[index] = incrementDigit(digits[index])
                return String(digits)
            }
        }
    }

    private func paddedFraction(_ fraction: String, digits: Int) -> String {
        let prefix = String(fraction.prefix(digits))
        let paddingCount = max(0, digits - prefix.count)
        return prefix + String(repeating: "0", count: paddingCount)
    }

    private func minimumFraction(digits: Int) -> String {
        String(repeating: "0", count: max(0, digits - 1)) + "1"
    }

    private func isZero(integer: String, fraction: String) -> Bool {
        integer == "0" && fraction.allSatisfy { $0 == "0" }
    }

    /// Apply digit grouping (thousands separator)
    private func applyGrouping(_ integer: String) -> String {
        guard config.groupDigits && integer.count > 3 else { return integer }

        var parts: [Substring] = []
        var index = integer.endIndex

        while index > integer.startIndex {
            let start = integer.index(index, offsetBy: -3, limitedBy: integer.startIndex) ?? integer.startIndex
            parts.append(integer[start ..< index])
            index = start
        }

        return parts.reversed().joined(separator: Constants.groupingSeparator)
    }

    /// Build the final formatted string with sign, grouping, and accessory
    private func buildFormattedString(
        integer: String,
        fraction: String?,
        isNegative: Bool,
        accessory: AmountAccessoryType,
        isLessThanMinimum: Bool,
        isZero: Bool,
        isPercent: Bool = false
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
        let signPrefix: String?
        if !isZero {
            switch config.signPolicy {
            case .negativeOnly:
                if isNegative {
                    signPrefix = String.Symbol.minus + config.space
                } else {
                    signPrefix = nil
                }
            case .always:
                signPrefix = (isNegative ? String.Symbol.minus : String.Symbol.plus) + config.space
            case .none:
                signPrefix = nil
            }
        } else {
            signPrefix = nil
        }

        if !isLessThanMinimum, let signPrefix {
            numberString = signPrefix + numberString
        }

        // Apply accessory (symbol or currency)
        let formatted: String
        switch accessory {
        case .none:
            formatted = numberString
        case let .token(currency),
             let .fiat(currency):
            let accessorySpace = space(for: currency.symbol)
            formatted = currency.symbolOnLeft
                ? currency.symbol + accessorySpace + numberString
                : numberString + accessorySpace + currency.symbol
        }

        if isLessThanMinimum {
            return (signPrefix ?? "") + "< " + formatted
        }

        if isPercent {
            return formatted + config.space + "%"
        }

        return formatted
    }

    private func space(for symbol: String) -> String {
        hasOnlyASCIILatinLetters(symbol) ? " " : "\u{2009}"
    }

    private func hasOnlyASCIILatinLetters(_ symbol: String) -> Bool {
        !symbol.isEmpty && symbol.unicodeScalars.allSatisfy { scalar in
            (65 ... 90).contains(scalar.value) || (97 ... 122).contains(scalar.value)
        }
    }
}

private extension AmountSignPolicy {
    /// iOS `.none` means "never a sign", which is ChainKit's `Hidden` — its `None` still keeps a
    /// natural minus.
    var chainKitSignMode: SignMode {
        switch self {
        case .negativeOnly: .minusonly
        case .always: .all
        case .none: .hidden
        }
    }
}
