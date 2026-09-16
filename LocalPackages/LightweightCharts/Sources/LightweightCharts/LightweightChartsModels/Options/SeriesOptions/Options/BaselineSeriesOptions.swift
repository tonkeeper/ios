import Foundation

/**
 * Represents style options for a baseline series.
 */
public struct BaselineSeriesOptions: SeriesOptionsCommon, Sendable {
    public var lastValueVisible: Bool?
    public var title: String?
    public var priceScaleId: String?
    public var visible: Bool?
    public var hitTestTolerance: Double?
    public var priceLineVisible: Bool?
    public var priceLineSource: PriceLineSource?
    public var priceLineWidth: LineWidth?
    public var priceLineColor: ChartColor?
    public var priceLineStyle: LineStyle?
    public var priceFormat: PriceFormat?
    public var baseLineVisible: Bool?
    public var baseLineColor: ChartColor?
    public var baseLineWidth: LineWidth?
    public var baseLineStyle: LineStyle?
    public var autoscaleInfoProvider: AutoscaleInfoProvider?
    public var conflationThresholdFactor: Double?

    /**
     * Base value of the series.
     */
    public var baseValue: BaseValueType?

    /**
     * Whether the gradient should be relative to the base value and visible range.
     */
    public var relativeGradient: Bool?

    /**
     * The first color of the top area.
     */
    public var topFillColor1: ChartColor?

    /**
     * The second color of the top area.
     */
    public var topFillColor2: ChartColor?

    /**
     * The line color of the top area.
     */
    public var topLineColor: ChartColor?

    /**
     * The first color of the bottom area.
     */
    public var bottomFillColor1: ChartColor?

    /**
     * The second color of the bottom area.
     */
    public var bottomFillColor2: ChartColor?

    /**
     * The line color of the bottom area.
     */
    public var bottomLineColor: ChartColor?

    /**
     * Line width.
     */
    public var lineWidth: LineWidth?

    /**
     * Line style.
     */
    public var lineStyle: LineStyle?

    /**
     * Line type.
     */
    public var lineType: LineType?

    /**
     * Show series line.
     */
    public var lineVisible: Bool?

    /**
     * Show the crosshair marker.
     */
    public var crosshairMarkerVisible: Bool?

    /**
     * Crosshair marker radius in pixels.
     */
    public var crosshairMarkerRadius: Double?

    /**
     * Crosshair marker border color. An empty string falls back to the the color of the series under the crosshair.
     */
    public var crosshairMarkerBorderColor: String?

    /**
     * The crosshair marker background color. An empty string falls back to the the color of the series under the crosshair.
     */
    public var crosshairMarkerBackgroundColor: String?

    /**
     * Crosshair marker border width in pixels.
     */
    public var crosshairMarkerBorderWidth: Double?

    /**
     * Show point markers on the line.
     */
    public var pointMarkersVisible: Bool?

    /**
     * Radius of point markers in pixels.
     */
    public var pointMarkersRadius: Double?

    /**
     * Last price animation mode.
     */
    public var lastPriceAnimation: LastPriceAnimationMode?

    public init(
        lastValueVisible: Bool? = nil,
        title: String? = nil,
        priceScaleId: String? = nil,
        visible: Bool? = nil,
        hitTestTolerance: Double? = nil,
        priceLineVisible: Bool? = nil,
        priceLineSource: PriceLineSource? = nil,
        priceLineWidth: LineWidth? = nil,
        priceLineColor: ChartColor? = nil,
        priceLineStyle: LineStyle? = nil,
        priceFormat: PriceFormat? = nil,
        baseLineVisible: Bool? = nil,
        baseLineColor: ChartColor? = nil,
        baseLineWidth: LineWidth? = nil,
        baseLineStyle: LineStyle? = nil,
        autoscaleInfoProvider: AutoscaleInfoProvider? = nil,
        conflationThresholdFactor: Double? = nil,
        baseValue: BaseValueType? = nil,
        relativeGradient: Bool? = nil,
        topFillColor1: ChartColor? = nil,
        topFillColor2: ChartColor? = nil,
        topLineColor: ChartColor? = nil,
        bottomFillColor1: ChartColor? = nil,
        bottomFillColor2: ChartColor? = nil,
        bottomLineColor: ChartColor? = nil,
        lineWidth: LineWidth? = nil,
        lineStyle: LineStyle? = nil,
        lineType: LineType? = nil,
        lineVisible: Bool? = nil,
        crosshairMarkerVisible: Bool? = nil,
        crosshairMarkerRadius: Double? = nil,
        crosshairMarkerBorderColor: String? = nil,
        crosshairMarkerBackgroundColor: String? = nil,
        crosshairMarkerBorderWidth: Double? = nil,
        pointMarkersVisible: Bool? = nil,
        pointMarkersRadius: Double? = nil,
        lastPriceAnimation: LastPriceAnimationMode? = nil
    ) {
        self.lastValueVisible = lastValueVisible
        self.title = title
        self.priceScaleId = priceScaleId
        self.visible = visible
        self.hitTestTolerance = hitTestTolerance
        self.priceLineVisible = priceLineVisible
        self.priceLineSource = priceLineSource
        self.priceLineWidth = priceLineWidth
        self.priceLineColor = priceLineColor
        self.priceLineStyle = priceLineStyle
        self.priceFormat = priceFormat
        self.baseLineVisible = baseLineVisible
        self.baseLineColor = baseLineColor
        self.baseLineWidth = baseLineWidth
        self.baseLineStyle = baseLineStyle
        self.autoscaleInfoProvider = autoscaleInfoProvider
        self.conflationThresholdFactor = conflationThresholdFactor
        self.baseValue = baseValue
        self.relativeGradient = relativeGradient
        self.topFillColor1 = topFillColor1
        self.topFillColor2 = topFillColor2
        self.topLineColor = topLineColor
        self.bottomFillColor1 = bottomFillColor1
        self.bottomFillColor2 = bottomFillColor2
        self.bottomLineColor = bottomLineColor
        self.lineWidth = lineWidth
        self.lineStyle = lineStyle
        self.lineType = lineType
        self.lineVisible = lineVisible
        self.crosshairMarkerVisible = crosshairMarkerVisible
        self.crosshairMarkerRadius = crosshairMarkerRadius
        self.crosshairMarkerBorderColor = crosshairMarkerBorderColor
        self.crosshairMarkerBackgroundColor = crosshairMarkerBackgroundColor
        self.crosshairMarkerBorderWidth = crosshairMarkerBorderWidth
        self.pointMarkersVisible = pointMarkersVisible
        self.pointMarkersRadius = pointMarkersRadius
        self.lastPriceAnimation = lastPriceAnimation
    }
}
