import Foundation

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

    init(tokenDecimals: Int, unit: Unit, usdPrice: Decimal? = nil) {
        self.tokenDecimals = tokenDecimals
        self.unit = usdPrice == nil ? .token : unit
        self.usdPrice = usdPrice
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
        text = PerpsDecimalInput.sanitize(newText, decimals: unit == .token ? tokenDecimals : Self.usdDecimals)
    }

    mutating func setUsdPrice(_ price: Decimal?) {
        usdPrice = price
        if !canToggleUnit, unit == .usd {
            unit = .token
            text = ""
        }
    }

    /// Carries the entry over into the other unit.
    mutating func toggleUnit() {
        guard canToggleUnit else { return }
        let token = tokenAmount
        let usd = usdAmount
        switch unit {
        case .token:
            unit = .usd
            text = usd.map { Self.text($0) } ?? ""
        case .usd:
            unit = .token
            text = token.map { Self.text($0) } ?? ""
        }
    }

    /// Fills in the whole balance. In dollars the value rounds down, so its conversion
    /// back stays within the balance.
    mutating func setMax(_ balance: Decimal) {
        switch unit {
        case .token:
            text = Self.text(Self.roundedDown(balance, scale: tokenDecimals))
        case .usd:
            guard let usdPrice else { return }
            text = Self.text(Self.roundedDown(balance * usdPrice, scale: Self.usdDecimals))
        }
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
