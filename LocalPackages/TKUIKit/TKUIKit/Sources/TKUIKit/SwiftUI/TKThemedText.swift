import SwiftUI

/// Themed counterpart of `AttributedString` for configs built outside the
/// SwiftUI environment (view models, mappers); resolve where rendered.
public struct TKThemedText: Hashable, Sendable {
    public struct Span: Hashable, Sendable {
        public var text: String
        /// `nil` — inherits the color of the rendering context.
        public var color: TKColor?

        public init(_ text: String, color: TKColor? = nil) {
            self.text = text
            self.color = color
        }
    }

    public var spans: [Span]

    public init(spans: [Span]) {
        self.spans = spans
    }

    public init(_ text: String, color: TKColor? = nil) {
        self.init(spans: [Span(text, color: color)])
    }

    public func resolve(_ palette: TKPalette) -> AttributedString {
        spans.reduce(into: AttributedString()) { result, span in
            var part = AttributedString(span.text)
            if let color = span.color {
                part.foregroundColor = color.resolve(palette)
            }
            result += part
        }
    }
}
