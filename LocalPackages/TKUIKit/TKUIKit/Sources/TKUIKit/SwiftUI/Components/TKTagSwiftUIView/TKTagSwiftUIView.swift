import SwiftUI
import UIKit

public struct TKTagSwiftUIViewConfig: Hashable {
    public enum Style: Hashable {
        /// `tkPalette.text.secondary` on `tkPalette.background.contentTint`.
        case plain
        /// `tkPalette.text.secondary` with a `tkPalette.background.contentTint` border.
        case outline
        /// Accent-tinted text on a translucent accent background.
        case accent(TKColor)
        case custom(textColor: TKColor, backgroundColor: TKColor, borderColor: TKColor)
    }

    public var text: String
    public var style: Style
    public var textPadding: UIEdgeInsets
    public var backgroundPadding: UIEdgeInsets

    public init(
        text: String,
        style: Style,
        textPadding: UIEdgeInsets? = nil,
        backgroundPadding: UIEdgeInsets? = nil
    ) {
        self.text = text.uppercased()
        self.style = style
        self.textPadding = textPadding ?? Self.textPadding
        self.backgroundPadding = backgroundPadding ?? Self.backgroundPadding
    }

    public static func accentTag(
        text: String,
        accent: TKColor
    ) -> TKTagSwiftUIViewConfig {
        TKTagSwiftUIViewConfig(text: text, style: .accent(accent))
    }

    public static func tag(text: String) -> TKTagSwiftUIViewConfig {
        TKTagSwiftUIViewConfig(text: text, style: .plain)
    }

    public static func outlineTag(text: String) -> TKTagSwiftUIViewConfig {
        TKTagSwiftUIViewConfig(text: text, style: .outline)
    }

    public static func outlintTag(text: String) -> TKTagSwiftUIViewConfig {
        outlineTag(text: text)
    }

    public static let textPadding = UIEdgeInsets(top: 4, left: 5, bottom: 3, right: 5)
    public static let backgroundPadding = UIEdgeInsets(top: 0, left: 6, bottom: 1, right: 0)
}

public struct TKTagSwiftUIView: View {
    @Environment(\.tkPalette) private var palette

    public var config: TKTagSwiftUIViewConfig

    public init(config: TKTagSwiftUIViewConfig) {
        self.config = config
    }

    public var body: some View {
        Text(config.text)
            .textStyle(.body4)
            .foregroundStyle(textColor)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(config.textPadding.edgeInsets)
            .background(
                RoundedRectangle(
                    cornerRadius: Layout.cornerRadius,
                    style: .continuous
                )
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: Layout.cornerRadius,
                        style: .continuous
                    )
                    .stroke(borderColor, lineWidth: Layout.borderWidth)
                )
            )
            .padding(config.backgroundPadding.edgeInsets)
            .fixedSize()
    }

    private var textColor: Color {
        switch config.style {
        case .plain, .outline:
            palette.text.secondary
        case let .accent(accent):
            accent.resolve(palette)
        case let .custom(textColor, _, _):
            textColor.resolve(palette)
        }
    }

    private var backgroundColor: Color {
        switch config.style {
        case .plain:
            palette.background.contentTint
        case .outline:
            .clear
        case let .accent(accent):
            accent.opacity(0.16).resolve(palette)
        case let .custom(_, backgroundColor, _):
            backgroundColor.resolve(palette)
        }
    }

    private var borderColor: Color {
        switch config.style {
        case .plain, .accent:
            .clear
        case .outline:
            palette.background.contentTint
        case let .custom(_, _, borderColor):
            borderColor.resolve(palette)
        }
    }
}

private extension TKTagSwiftUIView {
    enum Layout {
        static let cornerRadius: CGFloat = 4
        static let borderWidth: CGFloat = 1
    }
}

private extension UIEdgeInsets {
    var edgeInsets: EdgeInsets {
        EdgeInsets(
            top: top,
            leading: left,
            bottom: bottom,
            trailing: right
        )
    }
}
