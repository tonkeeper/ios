import Foundation

/**
 A single line of text in a text watermark primitive.
 */
public struct WatermarkLine: Codable, Sendable {
    /**
     Text content of the line.
     */
    public var text: String

    /**
     Color of the text.
     */
    public var color: ChartColor

    /**
     Font size in pixels.
     */
    public var fontSize: Int

    /**
     Font family.
     */
    public var fontFamily: String

    /**
     Font style (e.g., "normal", "italic").
     */
    public var fontStyle: String

    /**
     Line height in pixels (optional).
     */
    public var lineHeight: Int?

    public init(
        text: String,
        color: ChartColor,
        fontSize: Int = 24,
        fontFamily: String = "-apple-system",
        fontStyle: String = "normal",
        lineHeight: Int? = nil
    ) {
        self.text = text
        self.color = color
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.fontStyle = fontStyle
        self.lineHeight = lineHeight
    }
}

// MARK: - Codable

extension WatermarkLine {
    enum CodingKeys: String, CodingKey {
        case text
        case color
        case fontSize
        case fontFamily
        case fontStyle
        case lineHeight
    }
}

// MARK: - Encodable helper

extension WatermarkLine {
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
