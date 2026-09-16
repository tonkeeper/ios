import SwiftUI
import UIKit

public enum TransactionCellConfig: Sendable, Equatable {
    case shimmer
    case content(TransactionCellContent)
}

public struct TransactionCellContent: Sendable, Equatable {
    public var icon: Icon
    public var title: String
    public var subtitle: Subtitle
    public var amount: Amount
    public var accessory: Accessory
    public var details: Details?
    public var nftPreview: NftPreview?
    public var messages: [Message]
    public var showsDivider: Bool

    public init(
        icon: Icon,
        title: String,
        subtitle: Subtitle,
        amount: Amount,
        accessory: Accessory,
        details: Details? = nil,
        nftPreview: NftPreview? = nil,
        messages: [Message] = [],
        showsDivider: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.accessory = accessory
        self.details = details
        self.nftPreview = nftPreview
        self.messages = messages
        self.showsDivider = showsDivider
    }
}

public extension TransactionCellContent {
    struct Icon: Sendable, Equatable {
        public enum Badge: Sendable, Equatable {
            case loader
        }

        public enum RenderingMode: Sendable, Equatable {
            case template
            case original
        }

        public var image: UIImage
        public var renderingMode: RenderingMode
        public var tint: TKColor
        public var backgroundColor: TKColor
        public var badge: Badge?

        public init(
            image: UIImage,
            renderingMode: RenderingMode = .template,
            tint: TKColor = .iconSecondary,
            backgroundColor: TKColor = .backgroundContentTint,
            badge: Badge? = nil
        ) {
            self.image = image
            self.renderingMode = renderingMode
            self.tint = tint
            self.backgroundColor = backgroundColor
            self.badge = badge
        }

        public static var sent: Icon {
            Icon(image: .TKUIKit.Icons.Size28.trayArrowUp)
        }

        public static var failed: Icon {
            Icon(image: .TKUIKit.Icons.Size28.exclamationmarkCircle)
        }
    }
}

private extension TransactionCellContent.Icon {
    var swiftUIRenderingMode: Image.TemplateRenderingMode {
        switch renderingMode {
        case .template:
            .template
        case .original:
            .original
        }
    }
}

public extension TransactionCellContent {
    struct Amount: Sendable, Equatable {
        public struct Span: Sendable, Equatable {
            public var text: String
            /// `nil` — colored by the amount `style`.
            public var color: TKColor?

            public init(text: String, color: TKColor? = nil) {
                self.text = text
                self.color = color
            }
        }

        public var spans: [Span]
        public var style: AmountStyle

        public init(
            title: String,
            style: AmountStyle
        ) {
            self.init(spans: [Span(text: title)], style: style)
        }

        public init(
            spans: [Span],
            style: AmountStyle
        ) {
            self.spans = spans
            self.style = style
        }
    }

    enum AmountStyle: Sendable, Equatable {
        case primary
        case positive
        case negative
        case secondary
        case tertiary
        case warning
    }
}

public extension TransactionCellContent {
    enum SubtitleStyle: Sendable, Equatable {
        case primary
        case disabled
    }

    struct Subtitle: Sendable, Equatable {
        public var text: String
        public var style: SubtitleStyle

        public init(
            text: String,
            style: SubtitleStyle
        ) {
            self.text = text
            self.style = style
        }
    }
}

public extension TransactionCellContent {
    struct Accessory: Sendable, Equatable {
        public struct Span: Sendable, Equatable {
            public var text: String
            /// `nil` — colored by the accessory `color`.
            public var color: TKColor?

            public init(text: String, color: TKColor? = nil) {
                self.text = text
                self.color = color
            }
        }

        public var spans: [Span]
        public var textStyle: TKTextStyle
        public var color: TKColor

        public init(
            text: String,
            textStyle: TKTextStyle = .body2,
            color: TKColor = .textSecondary
        ) {
            self.init(
                spans: [Span(text: text)],
                textStyle: textStyle,
                color: color
            )
        }

        public init(
            spans: [Span],
            textStyle: TKTextStyle = .body2,
            color: TKColor = .textSecondary
        ) {
            self.spans = spans
            self.textStyle = textStyle
            self.color = color
        }

        public static var stub: Accessory {
            Accessory(text: "")
        }
    }
}

public extension TransactionCellContent {
    struct DetailsTitle: Sendable, Equatable {
        public var text: String
        public var color: TKColor

        public init(
            text: String,
            color: TKColor = .textSecondary
        ) {
            self.text = text
            self.color = color
        }
    }

    struct DetailsAccessory: Sendable, Equatable {
        public var text: String
        public var textStyle: TKTextStyle
        public var color: TKColor

        public init(
            text: String,
            textStyle: TKTextStyle = .body2,
            color: TKColor = .textSecondary
        ) {
            self.text = text
            self.textStyle = textStyle
            self.color = color
        }
    }

    struct Details: Sendable, Equatable {
        public var title: DetailsTitle?
        public var accessory: DetailsAccessory?

        public init(
            title: DetailsTitle? = nil,
            accessory: DetailsAccessory? = nil
        ) {
            self.title = title
            self.accessory = accessory
        }
    }
}

public extension TransactionCellContent {
    typealias NftId = String

    struct NftPreview: Sendable, Equatable {
        public var id: NftId
        public var imageSource: AssetAvatarViewImageSource
        public var title: String
        public var subtitle: String
        public var subtitleColor: TKColor
        public var isVerified: Bool

        public init(
            id: NftId,
            imageSource: AssetAvatarViewImageSource,
            title: String,
            subtitle: String,
            subtitleColor: TKColor = .textSecondary,
            isVerified: Bool
        ) {
            self.id = id
            self.imageSource = imageSource
            self.title = title
            self.subtitle = subtitle
            self.subtitleColor = subtitleColor
            self.isVerified = isVerified
        }
    }
}

public extension TransactionCellContent {
    enum MessageStyle: Sendable, Hashable {
        case compact
        case regular
    }

    struct Message: Sendable, Hashable {
        public var id: String
        public var text: String
        public var style: MessageStyle

        public init(
            id: String,
            text: String,
            style: MessageStyle = .regular
        ) {
            self.id = id
            self.text = text
            self.style = style
        }
    }
}

public struct TransactionCell: View {
    @Environment(\.tkPalette) private var palette

    public var config: TransactionCellConfig
    public var onTap: () -> Void
    public var onTapNft: (TransactionCellContent.NftId) -> Void

    public init(
        config: TransactionCellConfig,
        onTap: @escaping () -> Void = {},
        onTapNft: @escaping (TransactionCellContent.NftId) -> Void = { _ in }
    ) {
        self.config = config
        self.onTap = onTap
        self.onTapNft = onTapNft
    }

    public var body: some View {
        Cell(
            config: .init(
                style: .grouped,
                showsDivider: showsDivider,
                verticalAlignment: .top,
                action: onTap
            ),
            leading: {
                CellAssetLeading {
                    leadingContent
                        .frame(
                            width: Layout.iconSize,
                            height: Layout.iconSize
                        )
                }
            },
            center: {
                CellCenter(
                    primaryRow: CellCenterPrimaryRow(
                        config: primaryRowConfig
                    ),
                    secondaryRow: VStack(alignment: .leading, spacing: 0) {
                        CellCenterSecondaryRow(
                            config: secondaryRowConfig
                        )
                        switch config {
                        case .shimmer:
                            EmptyView()
                        case let .content(content):
                            if let details = content.details {
                                detailsView(details)
                                    .padding(.top, Layout.detailRowTopPadding)
                            }
                            if let nftPreview = content.nftPreview {
                                nftPreviewView(nftPreview)
                                    .padding(.top, Layout.nftPreviewTopPadding)
                            }
                            ForEach(content.messages, id: \.self) { content in
                                message(content)
                            }
                        }
                    }
                )
                .padding(.top, Layout.centerTopPadding)
            }
        )
    }

    private var showsDivider: Bool {
        switch config {
        case .shimmer:
            false
        case let .content(content):
            content.showsDivider
        }
    }

    enum Layout {
        static let iconSize: CGFloat = 44
        static let badgeSize: CGFloat = 18
        static let badgeOffset: CGFloat = -6
        static let badgeBorderWidth: CGFloat = 2
        static let centerTopPadding: CGFloat = 2
        static let detailRowTopPadding: CGFloat = 3
        static let supplementaryTopInset: CGFloat = 8
        static let nftPreviewTopPadding: CGFloat = 9
    }
}

// MARK: - Leading

extension TransactionCell {
    @ViewBuilder
    private var leadingContent: some View {
        switch config {
        case .shimmer:
            ShimmerSwiftUIView(
                config: ShimmerSwiftUIView.Config(
                    color: .backgroundContentTint,
                    cornerRadius: .capsule
                )
            )
        case let .content(content):
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(content.icon.backgroundColor)

                Image(uiImage: content.icon.image)
                    .renderingMode(content.icon.swiftUIRenderingMode)
                    .foregroundStyle(content.icon.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let badge = content.icon.badge {
                    badgeView(badge)
                        .offset(
                            x: Layout.badgeOffset,
                            y: Layout.badgeOffset
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func badgeView(_ badge: TransactionCellContent.Icon.Badge) -> some View {
        switch badge {
        case .loader:
            let totalSize = Layout.badgeSize + Layout.badgeBorderWidth * 2
            ZStack(alignment: .center) {
                Circle()
                    .fill(.backgroundContent)
                    .frame(
                        width: totalSize,
                        height: totalSize
                    )
                Circle()
                    .fill(.backgroundContentTint)
                    .frame(
                        width: Layout.badgeSize,
                        height: Layout.badgeSize
                    )
                CircularLoader(
                    mode: .indeterminate,
                    preset: .custom(
                        CircularLoaderConfiguration(
                            lineWidth: 2,
                            progressColor: palette.icon.secondary,
                            trackColor: palette.icon.secondary.opacity(0.32),
                            size: CGSize(width: 10, height: 10),
                            contentPadding: 0
                        )
                    )
                )
            }
            .frame(
                width: totalSize,
                height: totalSize
            )
        }
    }
}

// MARK: - Primary Row

extension TransactionCell {
    private var primaryRowConfig: CellCenterPrimaryRow.Config {
        switch config {
        case .shimmer:
            .shimmer()
        case let .content(content):
            .content(
                .init(
                    title: content.title,
                    value: CellCenterPrimaryRow.ValueConfig(
                        title: amountTitle(content.amount),
                        appliesColor: false
                    )
                )
            )
        }
    }

    private func amountTitle(_ amount: TransactionCellContent.Amount) -> AttributedString {
        let styleColor = amountColor
        return amount.spans.reduce(into: AttributedString()) { result, span in
            var part = AttributedString(span.text)
            part.foregroundColor = (span.color ?? styleColor).resolve(palette)
            result += part
        }
    }

    private var amountColor: TKColor {
        switch config {
        case .shimmer:
            .textPrimary
        case let .content(content):
            switch content.amount.style {
            case .primary:
                .textPrimary
            case .positive:
                .accentGreen
            case .negative:
                .accentRed
            case .secondary:
                .textSecondary
            case .tertiary:
                .textTertiary
            case .warning:
                .accentOrange
            }
        }
    }
}

// MARK: - Secondary Row

extension TransactionCell {
    private var secondaryRowConfig: CellCenterSecondaryRow.Config {
        switch config {
        case .shimmer:
            .shimmer()
        case let .content(content):
            .content(
                .init(
                    value: .init(
                        title: content.subtitle.text,
                        textColor: secondaryRowSubtitleText,
                        truncationMode: .middle
                    ),
                    accessory: CellCenterSecondaryRow.AccessoryConfig(
                        title: accessoryTitle(content.accessory),
                        textStyle: content.accessory.textStyle,
                        color: content.accessory.color
                    )
                )
            )
        }
    }

    private func accessoryTitle(_ accessory: TransactionCellContent.Accessory) -> AttributedString {
        accessory.spans.reduce(into: AttributedString()) { result, span in
            var part = AttributedString(span.text)
            part.foregroundColor = (span.color ?? accessory.color).resolve(palette)
            result += part
        }
    }

    private var secondaryRowSubtitleText: TKColor {
        switch config {
        case .shimmer:
            .textSecondary
        case let .content(content):
            switch content.subtitle.style {
            case .primary:
                .textSecondary
            case .disabled:
                .textTertiary
            }
        }
    }
}

// MARK: - Details

extension TransactionCell {
    func detailsView(_ content: TransactionCellContent.Details) -> some View {
        HStack(spacing: 0) {
            if let title = content.title {
                Text(title.text)
                    .textStyle(.body2)
                    .foregroundStyle(title.color)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let accessory = content.accessory {
                Text(accessory.text)
                    .textStyle(accessory.textStyle)
                    .foregroundStyle(accessory.color)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - NFT Preview

extension TransactionCell {
    private enum NftPreviewLayout {
        static let imageSize: CGFloat = 64
        static let cornerRadius: CGFloat = 12
        static let textSpacing: CGFloat = -1
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 6
        static let verificationSpacing: CGFloat = 4
        static let verificationIconSize: CGFloat = 16
    }

    func nftPreviewView(_ preview: TransactionCellContent.NftPreview) -> some View {
        Button {
            onTapNft(preview.id)
        } label: {
            nftPreviewContent(preview)
        }
        .buttonStyle(TKTapAnimationButtonStyle())
    }

    func nftPreviewContent(_ preview: TransactionCellContent.NftPreview) -> some View {
        HStack(spacing: 0) {
            AssetAvatarView(
                imageSource: preview.imageSource,
                configuration: AssetAvatarView.Configuration(
                    imageSize: NftPreviewLayout.imageSize,
                    chainIconSize: 0,
                    chainIconPadding: 0,
                    chainIconOffsetX: 0,
                    chainIconOffsetY: 0
                ),
                shape: .rectangle()
            )

            VStack(alignment: .leading, spacing: NftPreviewLayout.textSpacing) {
                Text(preview.title)
                    .textStyle(.body2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: NftPreviewLayout.verificationSpacing) {
                    Text(preview.subtitle)
                        .textStyle(.body2)
                        .foregroundStyle(preview.subtitleColor)
                        .lineLimit(1)

                    if preview.isVerified {
                        SwiftUI.Image.TKUIKit.Icons.Size16.verification
                            .renderingMode(.template)
                            .foregroundStyle(.iconSecondary)
                            .frame(
                                width: NftPreviewLayout.verificationIconSize,
                                height: NftPreviewLayout.verificationIconSize
                            )
                    }
                }
            }
            .padding(.horizontal, NftPreviewLayout.horizontalPadding)
            .padding(.top, NftPreviewLayout.verticalPadding)
            .padding(.bottom, NftPreviewLayout.verticalPadding)
        }
        .background(.backgroundContentTint)
        .clipShape(
            RoundedRectangle(
                cornerRadius: NftPreviewLayout.cornerRadius,
                style: .continuous
            )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Messages

extension TransactionCell {
    private enum MessageLayout {
        static let compactCornerRadius: CGFloat = 18
        static let regularCornerRadius: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 9
    }

    private func message(_ content: TransactionCellContent.Message) -> some View {
        Text(content.text)
            .textStyle(.body2)
            .foregroundStyle(.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MessageLayout.horizontalPadding)
            .padding(.top, MessageLayout.topPadding)
            .padding(.bottom, MessageLayout.bottomPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: messageCornerRadius(for: content.style),
                    style: .continuous
                )
                .fill(.backgroundContentTint)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Layout.supplementaryTopInset)
    }

    private func messageCornerRadius(for style: TransactionCellContent.MessageStyle) -> CGFloat {
        switch style {
        case .compact:
            MessageLayout.compactCornerRadius
        case .regular:
            MessageLayout.regularCornerRadius
        }
    }
}

//
// public struct TransactionCell: View {
//    public struct Item: Identifiable {
//        public struct MessageBubble: Identifiable {
//            public enum Style {
//                case compact
//                case regular
//            }
//
//            public let id: String
//            public let text: String
//            public let style: Style
//
//            public init(
//                id: String,
//                text: String,
//                style: Style = .regular
//            ) {
//                self.id = id
//                self.text = text
//                self.style = style
//            }
//        }
//
//        public let id: String
//        public let icon: Icon
//        public let title: String
//        public let subtitle: String
//        public let subtitleStyle: SubtitleStyle
//        public let amountText: String
//        public let amountStyle: AmountStyle
//        public let secondaryAccessoryText: String
//        public let secondaryAccessoryTextStyle: TKTextStyle
//        public let secondaryAccessoryColor: Color
//        public let detailRow: DetailRow?
//        public let nftPreview: NFTPreview?
//        public let messages: [MessageBubble]
//        public let action: (() -> Void)?
//
//        public init(
//            id: String,
//            icon: Icon,
//            title: String,
//            subtitle: String,
//            subtitleStyle: SubtitleStyle = .primary,
//            amountText: String,
//            amountStyle: AmountStyle = .primary,
//            dateText: String,
//            secondaryAccessoryTextStyle: TKTextStyle = .body2,
//            secondaryAccessoryColor: Color = palette.text.secondary,
//            detailRow: DetailRow? = nil,
//            nftPreview: NFTPreview? = nil,
//            messages: [MessageBubble] = [],
//            action: (() -> Void)? = nil
//        ) {
//            self.id = id
//            self.icon = icon
//            self.title = title
//            self.subtitle = subtitle
//            self.subtitleStyle = subtitleStyle
//            self.amountText = amountText
//            self.amountStyle = amountStyle
//            secondaryAccessoryText = dateText
//            self.secondaryAccessoryTextStyle = secondaryAccessoryTextStyle
//            self.secondaryAccessoryColor = secondaryAccessoryColor
//            self.detailRow = detailRow
//            self.nftPreview = nftPreview
//            self.messages = messages
//            self.action = action
//        }
//    }
//
//    private let items: [Item]
//
//    public init(items: [Item]) {
//        self.items = items
//    }
//
//    public var body: some View {
//        VStack(spacing: 0) {
//            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
//                rowContentView(
//                    item: item,
//                    showsSeparator: index < items.count - 1
//                )
//            }
//        }
//        .asCellsGroup()
//    }
//
//    private func rowContentView(
//        item: Item,
//        showsSeparator: Bool
//    ) -> some View {
//
//    }
// }
