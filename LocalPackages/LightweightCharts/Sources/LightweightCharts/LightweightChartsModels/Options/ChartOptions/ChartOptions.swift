import Foundation

/**
 * Side of the price scale - left or right
 */
public enum PriceScaleSide: String, Codable, Sendable {
    case left
    case right
}

/**
 * Structure describing options of the chart. Series options are to be set separately
 */
public struct ChartOptions: Codable, Sendable {
    /**
     Width of the chart
     */
    public var width: Double?

    /**
     Height of the chart
     */
    public var height: Double?

    /**
     Setting this flag to `true` will make the chart watch the chart container's size and automatically resize the chart to fit its container whenever the size changes
     */
    public var autoSize: Bool?

    /**
     Structure with watermark options

     - Deprecated: Watermark is no longer a chart option in v5. Use the new watermark plugin API:
       `chart.createTextWatermark(paneIndex:options:)` instead. See MIGRATION_V4_TO_V5.md for details.
     */
    @available(*, deprecated, message: "Watermark is no longer a chart option in v5. Use chart.createTextWatermark(paneIndex:options:) instead. See MIGRATION_V4_TO_V5.md for details.")
    public var watermark: DeprecatedWatermarkOptions? {
        get { return _watermark }
        set {
            _watermark = newValue
            _watermarkWasExplicitlySet = true
        }
    }

    var _watermark: DeprecatedWatermarkOptions?
    var _watermarkWasExplicitlySet: Bool = false

    /**
     Structure with layout options
     */
    public var layout: LayoutOptions?

    /**
     Structure with price scale option for left price scale
     */
    public var leftPriceScale: VisiblePriceScaleOptions?

    /**
     Structure with price scale option for right price scale
     */
    public var rightPriceScale: VisiblePriceScaleOptions?

    /**
     The visible price scale to use as the default, when a series doesn't specify a price scale id
     */
    public var defaultVisiblePriceScaleId: PriceScaleSide?

    /**
     Structure describing default price scale options for overlays
     */
    public var overlayPriceScales: OverlayPriceScaleOptions?

    /**
     Structure with time scale options
     */
    public var timeScale: TimeScaleOptions?

    /**
     Structure with crosshair options
     */
    public var crosshair: CrosshairOptions?

    /**
     Structure with grid options
     */
    public var grid: GridOptions?

    /**
     Structure with localization options
     */
    public var localization: LocalizationOptions?

    /**
     Structure that describes scrolling behavior or boolean flag that disables/enables all kinds of scrolls
     */
    public var handleScroll: HandleScrollOptions?

    /**
     Structure that describes scaling behavior or boolean flag that disables/enables all kinds of scales
     */
    public var handleScale: TogglableOptions<HandleScaleOptions>?

    /**
     Structure that describes kinetic scroll behavior
     */
    public var kineticScroll: KineticScrollOptions?

    /**
     Represent options for the tracking mode's behavior.
     */
    public var trackingMode: TrackingModeOptions?

    public var addDefaultPane: Bool?

    /**
     When `true`, the currently hovered series is rendered on top of all other series
     */
    public var hoveredSeriesOnTop: Bool?

    public init(
        width: Double? = nil,
        height: Double? = nil,
        autoSize: Bool? = nil,
        watermark: DeprecatedWatermarkOptions? = nil,
        layout: LayoutOptions? = nil,
        leftPriceScale: VisiblePriceScaleOptions? = nil,
        rightPriceScale: VisiblePriceScaleOptions? = nil,
        defaultVisiblePriceScaleId: PriceScaleSide? = nil,
        overlayPriceScales: OverlayPriceScaleOptions? = nil,
        timeScale: TimeScaleOptions? = nil,
        crosshair: CrosshairOptions? = nil,
        grid: GridOptions? = nil,
        localization: LocalizationOptions? = nil,
        handleScroll: HandleScrollOptions? = nil,
        handleScale: TogglableOptions<HandleScaleOptions>? = nil,
        kineticScroll: KineticScrollOptions? = nil,
        trackingMode: TrackingModeOptions? = nil,
        addDefaultPane: Bool? = nil,
        hoveredSeriesOnTop: Bool? = nil
    ) {
        self.width = width
        self.height = height
        self.autoSize = autoSize
        self._watermark = watermark
        self._watermarkWasExplicitlySet = watermark != nil
        self.layout = layout
        self.leftPriceScale = leftPriceScale
        self.rightPriceScale = rightPriceScale
        self.defaultVisiblePriceScaleId = defaultVisiblePriceScaleId
        self.overlayPriceScales = overlayPriceScales
        self.timeScale = timeScale
        self.crosshair = crosshair
        self.grid = grid
        self.localization = localization
        self.handleScroll = handleScroll
        self.handleScale = handleScale
        self.kineticScroll = kineticScroll
        self.trackingMode = trackingMode
        self.addDefaultPane = addDefaultPane
        self.hoveredSeriesOnTop = hoveredSeriesOnTop
    }

    enum CodingKeys: String, CodingKey {
        case width, height, autoSize, layout, leftPriceScale, rightPriceScale, defaultVisiblePriceScaleId, overlayPriceScales, timeScale, crosshair, grid, localization, handleScroll, handleScale, kineticScroll, trackingMode, addDefaultPane, hoveredSeriesOnTop
        case _watermark = "watermark"
    }
}

// MARK: -

extension ChartOptions {
    /// Options struct for JS serialization that excludes deprecated properties
    private struct JSChartOptions: Encodable {
        var width: Double?
        var height: Double?
        var autoSize: Bool?
        var layout: LayoutOptions?
        var leftPriceScale: VisiblePriceScaleOptions?
        var rightPriceScale: VisiblePriceScaleOptions?
        var defaultVisiblePriceScaleId: PriceScaleSide?
        var overlayPriceScales: OverlayPriceScaleOptions?
        var timeScale: TimeScaleOptions?
        var crosshair: CrosshairOptions?
        var grid: GridOptions?
        var localization: LocalizationOptions?
        var handleScroll: HandleScrollOptions?
        var handleScale: TogglableOptions<HandleScaleOptions>?
        var kineticScroll: KineticScrollOptions?
        var trackingMode: TrackingModeOptions?
        var addDefaultPane: Bool?
        var hoveredSeriesOnTop: Bool?

        init(_ options: ChartOptions) {
            self.width = options.width
            self.height = options.height
            self.autoSize = options.autoSize
            self.layout = options.layout
            self.leftPriceScale = options.leftPriceScale
            self.rightPriceScale = options.rightPriceScale
            self.defaultVisiblePriceScaleId = options.defaultVisiblePriceScaleId
            self.overlayPriceScales = options.overlayPriceScales
            self.timeScale = options.timeScale
            self.crosshair = options.crosshair
            self.grid = options.grid
            self.localization = options.localization
            self.handleScroll = options.handleScroll
            self.handleScale = options.handleScale
            self.kineticScroll = options.kineticScroll
            self.trackingMode = options.trackingMode
            self.addDefaultPane = options.addDefaultPane
            self.hoveredSeriesOnTop = options.hoveredSeriesOnTop
        }
    }

    func optionsScript(for closuresStore: ClosuresStore?) -> (options: String, variableName: String) {
        let variableName = "options"
        // Use JSChartOptions which excludes the deprecated watermark property (task 4.3)
        let jsOptions = JSChartOptions(self)
        var builder = JavaScriptOptionsScriptBuilder(variableName: variableName, baseJSON: jsOptions.jsonString, closuresStore: closuresStore)
        builder.assign("localization.priceFormatter", formatter: localization?.priceFormatterJSFunction, ensureObject: "localization")
        builder.assign("localization.timeFormatter", formatter: localization?.timeFormatterJSFunction, ensureObject: "localization")
        builder.assign("localization.percentageFormatter", formatter: localization?.percentageFormatterJSFunction, ensureObject: "localization")
        builder.assign("localization.tickmarksPriceFormatter", formatter: localization?.tickmarksPriceFormatterJSFunction, ensureObject: "localization")
        builder.assign("localization.tickmarksPercentageFormatter", formatter: localization?.tickmarksPercentageFormatterJSFunction, ensureObject: "localization")
        builder.assign("timeScale.tickMarkFormatter", formatter: timeScale?.tickMarkFormatterJSFunction, ensureObject: "timeScale")
        return (builder.script, variableName)
    }
}
