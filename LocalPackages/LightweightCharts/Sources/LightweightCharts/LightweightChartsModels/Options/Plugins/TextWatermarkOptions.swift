import Foundation

/**
 Options for creating a text watermark primitive on a pane.

 Text watermarks are created via `ChartApi.createTextWatermark(paneIndex:options:)`
 and return a handle that can be used to update or remove the watermark.
 */
public struct TextWatermarkOptions: Codable, Sendable {
    /**
     Visibility of the watermark.
     */
    public var visible: Bool

    /**
     Horizontal alignment within the pane.
     */
    public var horizontalAlignment: HorizontalAlignment

    /**
     Vertical alignment within the pane.
     */
    public var verticalAlignment: VerticalAlignment

    /**
     Lines of text to display in the watermark.
     */
    public var lines: [WatermarkLine]

    public init(
        visible: Bool = true,
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        lines: [WatermarkLine]
    ) {
        self.visible = visible
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.lines = lines
    }

    /// Convenience initializer with a single text line.
    public init(
        visible: Bool = true,
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        text: String,
        color: ChartColor,
        fontSize: Int = 24,
        fontFamily: String = "-apple-system",
        fontStyle: String = "normal",
        lineHeight: Int? = nil
    ) {
        self.visible = visible
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.lines = [
            WatermarkLine(
                text: text,
                color: color,
                fontSize: fontSize,
                fontFamily: fontFamily,
                fontStyle: fontStyle,
                lineHeight: lineHeight
            ),
        ]
    }

    /// Compatibility initializer for v4 (deprecated)
    @available(*, deprecated, message: "Use the new v5 API order with horizontalAlignment and verticalAlignment at the beginning")
    public init(
        text: String,
        color: ChartColor,
        fontSize: Int = 24,
        fontFamily: String = "-apple-system",
        fontStyle: String = "normal",
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center
    ) {
        self.init(
            visible: true,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            text: text,
            color: color,
            fontSize: fontSize,
            fontFamily: fontFamily,
            fontStyle: fontStyle
        )
    }
}

// MARK: - Codable

extension TextWatermarkOptions {
    enum CodingKeys: String, CodingKey {
        case visible
        case horizontalAlignment = "horzAlign"
        case verticalAlignment = "vertAlign"
        case lines
    }
}

// MARK: - Encodable helper

extension TextWatermarkOptions {
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}

/**
 Partial options for updating an existing text watermark.
 */
public struct TextWatermarkUpdateOptions: Codable, Sendable {
    public var visible: Bool?
    public var horizontalAlignment: HorizontalAlignment?
    public var verticalAlignment: VerticalAlignment?
    public var lines: [WatermarkLine]?

    public init(
        visible: Bool? = nil,
        horizontalAlignment: HorizontalAlignment? = nil,
        verticalAlignment: VerticalAlignment? = nil,
        lines: [WatermarkLine]? = nil
    ) {
        self.visible = visible
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.lines = lines
    }

    func merged(with current: TextWatermarkOptions) -> TextWatermarkOptions {
        TextWatermarkOptions(
            visible: visible ?? current.visible,
            horizontalAlignment: horizontalAlignment ?? current.horizontalAlignment,
            verticalAlignment: verticalAlignment ?? current.verticalAlignment,
            lines: lines ?? current.lines
        )
    }
}

// MARK: - Codable

extension TextWatermarkUpdateOptions {
    enum CodingKeys: String, CodingKey {
        case visible
        case horizontalAlignment = "horzAlign"
        case verticalAlignment = "vertAlign"
        case lines
    }
}

// MARK: - Encodable helper

extension TextWatermarkUpdateOptions {
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
