import Foundation

public struct Currency: Hashable, Codable, RawRepresentable, Sendable {
    public let code: String

    public var rawValue: String {
        code
    }

    public init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return nil }
        // Legacy code, kept for persisted state and backend strings
        code = normalized == Self.legacyGramCode ? TonInfo.symbol : normalized
    }

    public init?(code: String) {
        self.init(rawValue: code)
    }

    private init(known code: String) {
        self.code = code
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(String.self)
        guard let currency = Currency(code: code) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Empty currency code"
            )
        }
        self = currency
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static let legacyGramCode = "TON"

    public static let USD = Currency(known: "USD")
    public static let GRAM = Currency(known: TonInfo.symbol)
    public static let BTC = Currency(known: "BTC")

    public static var defaultCurrency: Currency {
        .USD
    }

    public var symbol: String {
        Self.symbols[code] ?? code
    }

    public var symbolOnLeft: Bool {
        Self.symbolOnLeftCodes.contains(code)
    }

    private static let symbols: [String: String] = [
        "USD": "$",
        "JPY": "¥",
        "EUR": "€",
        "CHF": "₣",
        "CNY": "¥",
        "GBP": "£",
        "IDR": "Rp",
        "INR": "₹",
        "KRW": "₩",
        "KZT": "₸",
        "RUB": "₽",
        "UAH": "₴",
        "UZS": "sum",
        "BYN": "Br",
        "BRL": "R$",
        "TRY": "₺",
        "NGN": "₦",
        "THB": "฿",
        "BDT": "৳",
        "CAD": "C$",
        "ILS": "₪",
        "GEL": "₾",
        "VND": "đ",
        "ZAR": "R‎",
        "ARS": "$",
        "COP": "$",
        "ETB": "ብር",
        "KES": "KSh",
        "UGX": "USh",
        "VES": "Bs",
        "AUD": "AU$",
        "BTC": "₿",
        "GRAM": "GRAM",
    ]

    private static let symbolOnLeftCodes: Set<String> = ["EUR", "USD", "GBP", "BDT", "CAD", "ILS", "AUD"]
}

extension Currency: CurrencyDisplayable {}

public extension Currency {
    var currencyDisplayType: CurrencyDisplayType {
        switch self {
        case .GRAM, .BTC:
            return .token
        default:
            return .fiat
        }
    }
}

public struct RemoteCurrency: Codable {
    @frozen public enum CurrencyType: String {
        case fiat
        case crypto
    }

    public let code: String
    public let name: String
    public let image: String
    public let type: String
    public let symbol: String

    public var currencyType: CurrencyType {
        CurrencyType(rawValue: type) ?? .fiat
    }

    public static var `default`: RemoteCurrency {
        RemoteCurrency(
            code: "USD",
            name: "US Dollar",
            image: "https://tonkeeper.com/assets/currencies/USD.png",
            type: "fiat",
            symbol: "$"
        )
    }

    public var legacyCurrency: Currency {
        Currency(code: code) ?? .USD
    }
}
