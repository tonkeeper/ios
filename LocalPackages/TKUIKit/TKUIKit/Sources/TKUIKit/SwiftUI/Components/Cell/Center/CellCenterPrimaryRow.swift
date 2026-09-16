import SwiftUI

public struct CellCenterPrimaryRow: View {
    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        switch config {
        case let .content(content):
            contentView(content)
        case let .shimmer(primaryWidth, secondaryWidth):
            shimmerView(primaryWidth: primaryWidth, secondaryWidth: secondaryWidth)
        }
    }

    private func contentView(_ content: Content) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(content.title.text)
                .textStyle(content.title.style)
                .foregroundStyle(content.title.color)
                .lineLimit(1)

            if !content.tags.isEmpty {
                ForEach(Array(content.tags.enumerated()), id: \.offset) { _, tag in
                    TKTagSwiftUIView(config: tag)
                }
                .offset(y: -1)
            }

            if !content.statusIcons.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(content.statusIcons.enumerated()), id: \.offset) { _, status in
                        statusIconView(status: status)
                    }
                }
                .padding(.leading, 4)
                .padding(.bottom, 1)
            }
            Spacer(minLength: 0)
            if let value = content.value {
                valueView(value)
            }
        }
    }

    @ViewBuilder
    private func valueView(_ value: ValueConfig) -> some View {
        let text = Text(value.title)
            .textStyle(value.style)
            .lineLimit(1)

        if value.appliesColor {
            text.foregroundStyle(value.color)
        } else {
            text
        }
    }

    private func shimmerView(primaryWidth: CGFloat, secondaryWidth: CGFloat?) -> some View {
        HStack(alignment: .center, spacing: 0) {
            ShimmerSwiftUIView(
                config: ShimmerSwiftUIView.Config(
                    color: .backgroundContentTint,
                    cornerRadius: .capsule
                )
            )
            .frame(width: primaryWidth, height: Self.shimmerTextContentHeight)
            .padding(.vertical, (Self.defaultTitleTextStyle.lineHeight - Self.shimmerTextContentHeight) / 2)

            Spacer(minLength: 0)
            if let secondaryWidth {
                ShimmerSwiftUIView(
                    config: ShimmerSwiftUIView.Config(
                        color: .backgroundContentTint,
                        cornerRadius: .capsule
                    )
                )
                .frame(width: secondaryWidth, height: Self.shimmerTextContentHeight)
                .padding(.vertical, (Self.defaultTitleTextStyle.lineHeight - Self.shimmerTextContentHeight) / 2)
            }
        }
    }

    private func statusIconView(status: StatusIcon) -> some View {
        Image(uiImage: status.image)
            .resizable()
            .scaledToFit()
            .foregroundStyle(status.color)
            .frame(width: status.size, height: status.size)
    }

    private static var defaultTitleTextStyle: TKTextStyle {
        .label1
    }

    private static var defaultValueTextStyle: TKTextStyle {
        .label1
    }

    private static var shimmerTextContentHeight: CGFloat {
        12
    }
}

public extension CellCenterPrimaryRow {
    struct TitleConfig {
        public var text: String
        public var color: TKColor
        public var style: TKTextStyle

        public init(
            text: String,
            color: TKColor = .textPrimary,
            style: TKTextStyle? = nil
        ) {
            self.text = text
            self.color = color
            self.style = style ?? defaultTitleTextStyle
        }
    }

    struct ValueConfig {
        public var title: AttributedString
        public var color: TKColor
        public var style: TKTextStyle
        public var appliesColor: Bool

        public init(
            title: String,
            color: TKColor = .textPrimary,
            style: TKTextStyle? = nil
        ) {
            self.title = AttributedString(title)
            self.color = color
            self.style = style ?? defaultValueTextStyle
            self.appliesColor = true
        }

        public init(
            title: AttributedString,
            color: TKColor = .textPrimary,
            appliesColor: Bool = false,
            style: TKTextStyle? = nil
        ) {
            self.title = title
            self.color = color
            self.style = style ?? defaultValueTextStyle
            self.appliesColor = appliesColor
        }
    }

    struct StatusIcon {
        public var image: UIImage
        public var color: TKColor
        public var size: CGFloat

        public init(
            image: UIImage,
            color: TKColor = .iconTertiary,
            size: CGFloat
        ) {
            self.image = image
            self.color = color
            self.size = size
        }
    }

    enum Config {
        case content(Content)
        case shimmer(primaryWidth: CGFloat = 65, secondaryWidth: CGFloat? = 41)
    }

    struct Content {
        public var title: TitleConfig
        public var tags: [TKTagSwiftUIViewConfig]
        public var status: StatusIcon?
        public var statusIcons: [StatusIcon]
        public var value: ValueConfig?

        public init(
            title: TitleConfig,
            tags: [TKTagSwiftUIViewConfig]? = nil,
            status: StatusIcon? = nil,
            statusIcons: [StatusIcon]? = nil,
            value: ValueConfig? = nil
        ) {
            self.title = title
            self.tags = tags ?? []
            self.status = status
            self.statusIcons = statusIcons ?? status.map { [$0] } ?? []
            self.value = value
        }

        public init(
            title: String,
            tags: [TKTagSwiftUIViewConfig]? = nil,
            status: StatusIcon? = nil,
            statusIcons: [StatusIcon]? = nil,
            value: ValueConfig? = nil
        ) {
            self.title = TitleConfig(text: title)
            self.tags = tags ?? []
            self.status = status
            self.statusIcons = statusIcons ?? status.map { [$0] } ?? []
            self.value = value
        }
    }
}
