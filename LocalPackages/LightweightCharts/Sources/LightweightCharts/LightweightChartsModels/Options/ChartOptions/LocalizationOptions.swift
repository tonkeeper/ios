import Foundation

public struct LocalizationOptions: Sendable {
    // swiftlint:disable line_length
    /**
     * Current locale, which will be used for formatting dates.
     * [Documentation.](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl#Locale_identification_and_negotiation)
     */
    public var locale: String?
    // swiftlint:enable line_length

    /**
     * User-defined function for price formatting.
     * Could be used for some specific cases, that could not be covered with PriceFormat
     */
    public var priceFormatter: JavaScriptMethod<BarPrice, String>? {
        get {
            priceFormatterJSFunction?.function
        }
        set {
            priceFormatterJSFunction = newValue != nil ? JSFunction(function: newValue!) : nil
        }
    }

    /**
     * User-defined function for time formatting.
     */
    public var timeFormatter: JavaScriptMethod<EventTime, String>? {
        get {
            timeFormatterJSFunction?.function
        }
        set {
            timeFormatterJSFunction = newValue != nil ? JSFunction(function: newValue!) : nil
        }
    }

    /**
     * User-defined function for percentage value formatting.
     */
    public var percentageFormatter: JavaScriptMethod<BarPrice, String>? {
        get {
            percentageFormatterJSFunction?.function
        }
        set {
            percentageFormatterJSFunction = newValue != nil ? JSFunction(function: newValue!) : nil
        }
    }

    /**
     * User-defined function for tickmark price formatting.
     */
    public var tickmarksPriceFormatter: JavaScriptMethod<[BarPrice], [String]>? {
        get {
            tickmarksPriceFormatterJSFunction?.function
        }
        set {
            tickmarksPriceFormatterJSFunction = newValue != nil ? JSFunction(function: newValue!) : nil
        }
    }

    /**
     * User-defined function for tickmark percentage formatting.
     */
    public var tickmarksPercentageFormatter: JavaScriptMethod<[BarPrice], [String]>? {
        get {
            tickmarksPercentageFormatterJSFunction?.function
        }
        set {
            tickmarksPercentageFormatterJSFunction = newValue != nil ? JSFunction(function: newValue!) : nil
        }
    }

    /**
     * Date formatting string.
     * Might contains `yyyy`, `yy`, `MMMM`, `MMM`, `MM` and `dd` literals
     * which will be replaced with corresponding date's value.
     * Ignored if timeFormatter has been specified.
     */
    public var dateFormat: String?

    var priceFormatterJSFunction: JSFunction<BarPrice, String>?
    var timeFormatterJSFunction: JSFunction<EventTime, String>?
    var percentageFormatterJSFunction: JSFunction<BarPrice, String>?
    var tickmarksPriceFormatterJSFunction: JSFunction<[BarPrice], [String]>?
    var tickmarksPercentageFormatterJSFunction: JSFunction<[BarPrice], [String]>?

    public init(
        locale: String? = nil,
        dateFormat: String? = nil,
        priceFormatter: JavaScriptMethod<BarPrice, String>? = nil,
        timeFormatter: JavaScriptMethod<EventTime, String>? = nil,
        percentageFormatter: JavaScriptMethod<BarPrice, String>? = nil,
        tickmarksPriceFormatter: JavaScriptMethod<[BarPrice], [String]>? = nil,
        tickmarksPercentageFormatter: JavaScriptMethod<[BarPrice], [String]>? = nil
    ) {
        self.locale = locale
        self.dateFormat = dateFormat
        self.priceFormatter = priceFormatter
        self.timeFormatter = timeFormatter
        self.percentageFormatter = percentageFormatter
        self.tickmarksPriceFormatter = tickmarksPriceFormatter
        self.tickmarksPercentageFormatter = tickmarksPercentageFormatter
    }
}

// MARK: - Codable

extension LocalizationOptions: Codable {
    enum CodingKeys: String, CodingKey {
        case locale
        case dateFormat
    }
}
