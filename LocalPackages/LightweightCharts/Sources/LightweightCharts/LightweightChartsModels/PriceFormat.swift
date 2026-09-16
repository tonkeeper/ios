import Foundation

public enum PriceFormat: Sendable {
    case builtIn(BuiltInPriceFormat)
    case custom(CustomPriceFormat)
}

// MARK: - PriceFormat Codable

extension PriceFormat: Codable {
    // MARK: Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let builtInFormat = try? container.decode(BuiltInPriceFormat.self) {
            self = .builtIn(builtInFormat)
        } else if let customFormat = try? container.decode(CustomPriceFormat.self) {
            self = .custom(customFormat)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Error decoding \(type(of: self))"
            )
        }
    }

    // MARK: Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .builtIn(value):
            try container.encode(value)
        case let .custom(value):
            try container.encode(value)
        }
    }
}

// MARK: -

/// Enum of possible modes of price formatting
public enum PriceFormatBuilInType: String, Codable, Sendable {
    /// `price` is the most common choice; it allows customization of precision and rounding of prices
    case price
    /// `volume` uses abbreviation for formatting prices like '1.2K' or '12.67M'
    case volume
    /// `percent` uses '%' sign at the end of prices.
    case percent
}

// MARK: -

/**
 * Structure describing series values formatting
 * Fields precision and minMove allow wide customization of formatting
 * Example:
 *
 * `minMove = 0.01`, precision is not specified. Prices will change like 1.13, 1.14, 1.15 etc.
 *
 * `minMove = 0.01`, precision = 3. Prices will change like 1.130, 1.140, 1.150 etc.
 *
 * `minMove = 0.05`, precision is not specified. Prices will change like 1.10, 1.15, 1.20
 */
public struct BuiltInPriceFormat: Codable, Sendable {
    /**
     *  Enum of possible modes of price formatting
     * * `price` - is the most common choice; it allows customization of precision and rounding of prices
     * * `volume` - uses abbreviation for formatting prices like '1.2K' or '12.67M'
     * * `percent` -  uses '%' sign at the end of prices.
     */
    public var type: PriceFormatBuilInType

    /**
     * Number of digits after the decimal point.
     * If it is not set, then its value is calculated automatically based on minMove
     */
    public var precision: Double?

    /**
     * Minimal step of the price. This value shouldn't have more decimal digits than the precision
     */
    public var minMove: Double?

    /**
     * Optional base used for built-in price formatting.
     */
    public var base: Double?

    public init(type: PriceFormatBuilInType, precision: Double? = nil, minMove: Double? = nil, base: Double? = nil) {
        self.type = type
        self.precision = precision
        self.minMove = minMove
        self.base = base
    }
}

// MARK: -

public struct CustomPriceFormat: Sendable {
    private let type = "custom"

    /**
     * Minimal step of the price.
     */
    public var minMove: Double?

    /**
     * User-defined function for price formatting that could be used for some specific cases,
     * that could not be covered with PriceFormatBuiltIn
     */
    public var formatter: JavaScriptMethod<BarPrice, String>? {
        get {
            formatterJSFunction?.function
        }
        set {
            formatterJSFunction = newValue != nil ? JSFunction(function: newValue!) : nil
        }
    }

    /**
     * User-defined function for formatting tickmark labels.
     */
    public var tickmarksFormatter: JavaScriptMethod<[BarPrice], [String]>? {
        get {
            tickmarksFormatterJSFunction?.function
        }
        set {
            tickmarksFormatterJSFunction = newValue != nil ? JSFunction(function: newValue!) : nil
        }
    }

    var formatterJSFunction: JSFunction<BarPrice, String>?
    var tickmarksFormatterJSFunction: JSFunction<[BarPrice], [String]>?

    public init(
        minMove: Double?,
        formatter: JavaScriptMethod<BarPrice, String>,
        tickmarksFormatter: JavaScriptMethod<[BarPrice], [String]>? = nil
    ) {
        self.minMove = minMove
        self.formatter = formatter
        self.tickmarksFormatter = tickmarksFormatter
    }

    public init(
        minMove: Double?,
        formatter: @escaping (BarPrice) -> String,
        tickmarksFormatter: (([BarPrice]) -> [String])? = nil
    ) {
        self.init(
            minMove: minMove,
            formatter: .closure(formatter),
            tickmarksFormatter: tickmarksFormatter.map { .closure($0) }
        )
    }

    public init(
        minMove: Double?,
        formatterJavaScript: String,
        tickmarksFormatterJavaScript: String? = nil
    ) {
        self.init(
            minMove: minMove,
            formatter: .javaScript(formatterJavaScript),
            tickmarksFormatter: tickmarksFormatterJavaScript.map { .javaScript($0) }
        )
    }
}

// MARK: - CustomPriceFormat Codable

extension CustomPriceFormat: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case minMove
    }
}
