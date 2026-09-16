import Foundation

public struct RoundedCandlestickSeriesOptions: SeriesOptionsCommon, Sendable {
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

    public var upColor: ChartColor?
    public var downColor: ChartColor?
    public var wickVisible: Bool?
    public var wickUpColor: ChartColor?
    public var wickDownColor: ChartColor?
    public var bodyWidth: Double?
    public var wickWidth: Double?
    public var bodyMinHeight: Double?
    public var radius: Double?

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
        upColor: ChartColor? = nil,
        downColor: ChartColor? = nil,
        wickVisible: Bool? = nil,
        wickUpColor: ChartColor? = nil,
        wickDownColor: ChartColor? = nil,
        bodyWidth: Double? = nil,
        wickWidth: Double? = nil,
        bodyMinHeight: Double? = nil,
        radius: Double? = nil
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
        self.upColor = upColor
        self.downColor = downColor
        self.wickVisible = wickVisible
        self.wickUpColor = wickUpColor
        self.wickDownColor = wickDownColor
        self.bodyWidth = bodyWidth
        self.wickWidth = wickWidth
        self.bodyMinHeight = bodyMinHeight
        self.radius = radius
    }
}
