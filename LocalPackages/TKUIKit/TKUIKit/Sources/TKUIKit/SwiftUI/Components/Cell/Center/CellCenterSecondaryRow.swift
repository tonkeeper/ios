import SwiftUI

public struct CellCenterSecondaryRow: View {
    @Environment(\.tkPalette) private var palette

    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        switch config {
        case let .content(content):
            contentView(content)
        case let .shimmer(primaryWidth):
            shimmerView(primaryWidth: primaryWidth)
        }
    }

    private func contentView(_ content: Content) -> some View {
        HStack(spacing: 0) {
            if let value = content.value {
                Text(value.title)
                    .textStyle(value.textStyle)
                    .foregroundStyle(value.textColor)
                    .lineLimit(value.lineLimit)
                    .truncationMode(value.truncationMode)
            }
            if let delta = content.delta {
                Text(delta.text)
                    .textStyle(delta.textStyle)
                    .foregroundStyle(deltaColor(delta))
                    .padding(.leading, 6)
            }
            Spacer(minLength: 0)
            if let accessory = content.accessory {
                Text(accessory.title)
                    .textStyle(accessory.textStyle)
                    .foregroundStyle(accessory.color)
                    .lineLimit(accessory.lineLimit)
                    .truncationMode(accessory.truncationMode)
            }
        }
    }

    private func deltaColor(_ delta: Delta) -> Color {
        switch delta.style {
        case let .sign(isPositive):
            isPositive ? palette.accent.green : palette.accent.red
        case let .custom(color):
            color
        }
    }

    private func shimmerView(primaryWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ShimmerSwiftUIView(
                    config: ShimmerSwiftUIView.Config(
                        color: .backgroundContentTint,
                        cornerRadius: .capsule
                    )
                )
                .frame(width: primaryWidth, height: 12)
                Spacer(minLength: 0)
            }
            .frame(height: Self.defaultValueTextStyle.lineHeight)
            .padding(.vertical, -1)
        }
    }

    private static var defaultValueTextStyle: TKTextStyle {
        .body2
    }

    private static var defaultDeltaTextStyle: TKTextStyle {
        .body2
    }
}

public extension CellCenterSecondaryRow {
    struct ValueConfig {
        public var title: String
        public var textStyle: TKTextStyle
        public var lineLimit: Int
        public var textColor: TKColor
        public var truncationMode: Text.TruncationMode

        public init(
            title: String,
            textStyle: TKTextStyle? = nil,
            lineLimit: Int = 1,
            textColor: TKColor = .textSecondary,
            truncationMode: Text.TruncationMode = .tail
        ) {
            self.title = title
            self.textStyle = textStyle ?? defaultValueTextStyle
            self.lineLimit = lineLimit
            self.textColor = textColor
            self.truncationMode = truncationMode
        }
    }

    struct AccessoryConfig {
        public var title: AttributedString
        public var textStyle: TKTextStyle
        public var color: TKColor
        public var lineLimit: Int
        public var truncationMode: Text.TruncationMode

        public init(
            title: String,
            textStyle: TKTextStyle = .body2,
            color: TKColor = .textSecondary,
            lineLimit: Int = 1,
            truncationMode: Text.TruncationMode = .tail
        ) {
            self.init(
                title: AttributedString(title),
                textStyle: textStyle,
                color: color,
                lineLimit: lineLimit,
                truncationMode: truncationMode
            )
        }

        public init(
            title: AttributedString,
            textStyle: TKTextStyle = .body2,
            color: TKColor = .textSecondary,
            lineLimit: Int = 1,
            truncationMode: Text.TruncationMode = .tail
        ) {
            self.title = title
            self.textStyle = textStyle
            self.color = color
            self.lineLimit = lineLimit
            self.truncationMode = truncationMode
        }
    }

    struct Delta {
        /// Semantic style resolved against `tkPalette` where the delta is rendered.
        public enum Style {
            case sign(isPositive: Bool)
            case custom(Color)
        }

        public var text: String
        public var textStyle: TKTextStyle
        public var style: Style

        public init(
            text: String,
            textStyle: TKTextStyle? = nil,
            isPositive: Bool
        ) {
            self.text = text
            self.textStyle = textStyle ?? defaultDeltaTextStyle
            style = .sign(isPositive: isPositive)
        }
    }

    enum Config {
        case content(Content)
        case shimmer(primaryWidth: CGFloat = 170)
    }

    struct Content {
        public var value: ValueConfig?
        public var delta: Delta?
        public var accessory: AccessoryConfig?

        public init(
            value: ValueConfig? = nil,
            delta: Delta? = nil,
            accessory: AccessoryConfig? = nil
        ) {
            self.value = value
            self.delta = delta
            self.accessory = accessory
        }
    }
}
