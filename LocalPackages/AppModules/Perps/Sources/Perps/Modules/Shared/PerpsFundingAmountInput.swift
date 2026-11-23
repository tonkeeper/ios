import Foundation
import TKUIKit

/// The amount a funding screen is typed in, in either the token or dollars. What gets
/// paid is always `tokenAmount`: a dollar entry converts down to whole token units, so a
/// rounded conversion never asks for more than the dollars typed.
struct PerpsFundingAmountInput: Equatable {
    enum Unit: Equatable {
        case token
        case usd
    }

    static let usdDecimals = 2

    let tokenDecimals: Int
    private(set) var unit: Unit
    private(set) var text = ""
    /// Dollars per token; `nil` leaves the entry in the token and offers no conversion.
    private(set) var usdPrice: Decimal?
    private var unitToggle = AmountToggle<String>()

    init(tokenDecimals: Int, unit: Unit, usdPrice: Decimal? = nil) {
        self.tokenDecimals = tokenDecimals
        self.unit = usdPrice == nil ? .token : unit
        self.usdPrice = usdPrice
    }

    /// What the field shows of a token amount: no more digits than typing allows.
    private var textDecimals: Int {
        min(tokenDecimals, PerpsDecimalInput.maximumFractionDigits)
    }

    var canToggleUnit: Bool {
        usdPrice.map { $0 > 0 } ?? false
    }

    var tokenAmount: Decimal? {
        guard let entered = Self.decimal(text) else { return nil }
        switch unit {
        case .token:
            return entered
        case .usd:
            guard let usdPrice, usdPrice > 0 else { return nil }
            return Self.roundedDown(entered / usdPrice, scale: tokenDecimals)
        }
    }

    var usdAmount: Decimal? {
        guard let entered = Self.decimal(text) else { return nil }
        switch unit {
        case .usd:
            return entered
        case .token:
            // Down, as Max does: carried over into dollars, the entry must not outgrow the balance.
            return usdPrice.map { Self.roundedDown(entered * $0, scale: Self.usdDecimals) }
        }
    }

    mutating func setText(_ newText: String) {
        let sanitized = PerpsDecimalInput.sanitize(newText, decimals: unit == .token ? tokenDecimals : Self.usdDecimals)
        guard sanitized != text else { return }
        text = sanitized
        unitToggle.reset()
    }

    mutating func setUsdPrice(_ price: Decimal?) {
        if price != usdPrice {
            // Converted at the old price, the captured text would no longer match the counterpart shown.
            unitToggle.reset()
        }
        usdPrice = price
        if !canToggleUnit, unit == .usd {
            unit = .token
            text = ""
            unitToggle.reset()
        }
    }

    /// Carries the entry over into the other unit; toggling straight back restores it as it was.
    mutating func toggleUnit() {
        guard canToggleUnit else { return }
        let converted: Decimal?
        switch unit {
        case .token:
            converted = usdAmount
            unit = .usd
        case .usd:
            converted = tokenAmount.map { Self.roundedDown($0, scale: textDecimals) }
            unit = .token
        }
        text = unitToggle.toggle(text, converted: converted.map { Self.text($0) } ?? "")
    }

    /// The same entry against another token: dollars stay as typed, a token entry starts over.
    func repriced(tokenDecimals: Int, usdPrice: Decimal) -> PerpsFundingAmountInput {
        var repriced = PerpsFundingAmountInput(tokenDecimals: tokenDecimals, unit: unit, usdPrice: usdPrice)
        if unit == .usd { repriced.text = text }
        return repriced
    }

    /// Fills in a dollar limit. A token entry rounds down, so its dollar value stays within it.
    mutating func setMaxUsd(_ usd: Decimal) {
        switch unit {
        case .usd:
            text = Self.text(Self.roundedDown(usd, scale: Self.usdDecimals))
        case .token:
            guard let usdPrice, usdPrice > 0 else { return }
            text = Self.text(Self.roundedDown(usd / usdPrice, scale: textDecimals))
        }
        unitToggle.reset()
    }

    /// Fills in the whole balance. In dollars the value rounds down, so its conversion
    /// back stays within the balance.
    mutating func setMax(_ balance: Decimal) {
        switch unit {
        case .token:
            text = Self.text(Self.roundedDown(balance, scale: textDecimals))
        case .usd:
            guard let usdPrice else { return }
            text = Self.text(Self.roundedDown(balance * usdPrice, scale: Self.usdDecimals))
        }
        unitToggle.reset()
    }

    static func decimal(_ text: String) -> Decimal? {
        let posix = PerpsDecimalInput.normalized(text).trimmingCharacters(in: .whitespaces)
        guard !posix.isEmpty else { return nil }
        return Decimal(string: posix, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func text(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).description(withLocale: Locale(identifier: "en_US_POSIX"))
    }

    static func roundedDown(_ value: Decimal, scale: Int) -> Decimal {
        round(value, scale: scale, mode: .down)
    }

    private static func round(_ value: Decimal, scale: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, mode)
        return result
    }
}
