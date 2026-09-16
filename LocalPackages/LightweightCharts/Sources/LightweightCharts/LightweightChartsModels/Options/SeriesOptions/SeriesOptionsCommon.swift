import Foundation

/**
 * Structure describing options common for all types of series
 */
public protocol SeriesOptionsCommon: Codable, Sendable {
    /**
     Visibility of the label with the latest visible price on the price scale
     */
    var lastValueVisible: Bool? { get }

    /**
     Title of the series. This label is placed with price axis label
     */
    var title: String? { get }

    /**
     Target price scale to bind new series to
     */
    var priceScaleId: String? { get }

    /**
     Visibility of series.
     */
    var visible: Bool? { get }

    /**
     Additional tolerance in pixels used when hit testing the series
     */
    var hitTestTolerance: Double? { get }

    /**
     Visibility of the price line. Price line is a horizontal line indicating the last price of the series
     */
    var priceLineVisible: Bool? { get }

    /**
     Enum of possible modes of priceLine source
     */
    var priceLineSource: PriceLineSource? { get }

    /**
     Width of the price line. Ignored if priceLineVisible is false
     */
    var priceLineWidth: LineWidth? { get }

    /**
     Color of the price line. Ignored if priceLineVisible is false
     */
    var priceLineColor: ChartColor? { get }

    /**
     Price line style. Suitable for percentage and indexedTo100 scales
     */
    var priceLineStyle: LineStyle? { get }

    /**
     Formatting settings associated with the series
     */
    var priceFormat: PriceFormat? { get }

    /**
     Visibility of base line. Suitable for percentage and indexedTo100 scales
     */
    var baseLineVisible: Bool? { get }

    /**
     Color of the base line in IndexedTo100 mode
     */
    var baseLineColor: ChartColor? { get }

    /**
     Base line width. Suitable for percentage and indexedTo100 scales. Ignored if baseLineVisible is not set
     */
    var baseLineWidth: LineWidth? { get }

    /**
     Base line style. Suitable for percentage and indexedTo100 scales. Ignored if baseLineVisible is not set
     */
    var baseLineStyle: LineStyle? { get }

    /**
     Function that overrides calculating of visible prices range
     */
    var autoscaleInfoProvider: AutoscaleInfoProvider? { get }

    /**
     Per-series conflation threshold factor. Overrides the global time scale conflation threshold for this series
     */
    var conflationThresholdFactor: Double? { get }
}

// MARK: -

extension SeriesOptionsCommon {
    func optionsScript(for closuresStore: ClosuresStore?) -> (options: String, variableName: String) {
        let variableName = "options"
        var builder = JavaScriptOptionsScriptBuilder(variableName: variableName, baseJSON: jsonString, closuresStore: closuresStore)
        if case let .custom(customFormatter) = priceFormat, let formatter = customFormatter.formatterJSFunction {
            builder.assign("priceFormat.formatter", formatter: formatter, ensureObject: "priceFormat")
        }
        if case let .custom(customFormatter) = priceFormat, let formatter = customFormatter.tickmarksFormatterJSFunction {
            builder.assign("priceFormat.tickmarksFormatter", formatter: formatter, ensureObject: "priceFormat")
        }
        if let provider = autoscaleInfoProvider?.jsFunction {
            builder.assign("autoscaleInfoProvider", formatter: provider)
        }
        return (builder.script, variableName)
    }
}
