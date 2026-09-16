import Foundation

/**
 The color space to use for the chart rendering
 */
public enum ColorSpace: String, Codable, Sendable {
    case srgb
    case displayP3 = "display-p3"
}

/**
 Structure describing panes customizations
 */
public struct LayoutPanesOptions: Codable, Sendable {
    /**
     Enable resizing the panes by dragging the separator between them
     */
    public var enableResize: Bool?

    /**
     Color of the separator between panes
     */
    public var separatorColor: ChartColor?

    /**
     Color of the separator between panes when hovered
     */
    public var separatorHoverColor: ChartColor?

    public init(
        enableResize: Bool? = nil,
        separatorColor: ChartColor? = nil,
        separatorHoverColor: ChartColor? = nil
    ) {
        self.enableResize = enableResize
        self.separatorColor = separatorColor
        self.separatorHoverColor = separatorHoverColor
    }
}

/**
 Structure describing layout options
 */
public struct LayoutOptions: Codable, Sendable {
    public var background: SurfaceColor?

    /**
     Color of a text on the scales
     */
    public var textColor: ChartColor?

    /**
     Font size of a text on the scales in pixels
     */
    public var fontSize: Double?

    /**
     Font family of a text on the scales
     */
    public var fontFamily: String?

    /**
     Whether to show the TradingView attribution logo.
     If not set, upstream default behavior is preserved.
     */
    public var attributionLogo: Bool?

    /**
     Panes customizations
     */
    public var panes: LayoutPanesOptions?

    /**
     The color space to use for the chart rendering. The display-p3 color space
     provides a wider gamut of colors but requires a compatible display
     */
    public var colorSpace: ColorSpace?

    public init(
        background: SurfaceColor? = nil,
        textColor: ChartColor? = nil,
        fontSize: Double? = nil,
        fontFamily: String? = nil,
        attributionLogo: Bool? = nil,
        panes: LayoutPanesOptions? = nil,
        colorSpace: ColorSpace? = nil
    ) {
        self.background = background
        self.textColor = textColor
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.attributionLogo = attributionLogo
        self.panes = panes
        self.colorSpace = colorSpace
    }
}
