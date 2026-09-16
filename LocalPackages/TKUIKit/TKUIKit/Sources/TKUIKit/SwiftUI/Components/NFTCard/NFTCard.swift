import SwiftUI
import UIKit

public enum NFTCardConfig {
    case shimmer
    case content(NFTCardContent)
}

public struct NFTCardContent: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let subtitleColor: TKColor
    public let imageSource: NFTImageViewImageSource
    public let isSecureMode: Bool
    public let isOnSale: Bool

    public init(
        id: String,
        title: String,
        subtitle: String,
        subtitleColor: TKColor = .textSecondary,
        imageSource: NFTImageViewImageSource = .image(nil),
        isSecureMode: Bool = false,
        isOnSale: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.imageSource = imageSource
        self.isSecureMode = isSecureMode
        self.isOnSale = isOnSale
    }
}

public struct NFTCard: View {
    private let config: NFTCardConfig
    private let configuration: NFTImageView.Configuration
    private let action: (() -> Void)?

    public init(
        config: NFTCardConfig,
        imageSize: NFTImageView.Size = .medium,
        action: (() -> Void)? = nil
    ) {
        self.config = config
        self.configuration = imageSize.configuration
        self.action = action
    }

    public init(
        config: NFTCardConfig,
        configuration: NFTImageView.Configuration,
        action: (() -> Void)? = nil
    ) {
        self.config = config
        self.configuration = configuration
        self.action = action
    }

    public init(
        content: NFTCardContent,
        imageSize: NFTImageView.Size = .medium,
        action: @escaping () -> Void
    ) {
        self.init(
            config: .content(content),
            imageSize: imageSize,
            action: action
        )
    }

    public var body: some View {
        Group {
            if case .content = config, let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(NFTCardButtonStyle())
            } else {
                cardContent
            }
        }
        .frame(
            width: configuration.cardWidth,
            height: configuration.cardHeight
        )
    }
}

private extension NFTCard {
    var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea
            textArea
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    var imageArea: some View {
        switch config {
        case .shimmer:
            NFTImageView(
                imageSource: .shimmer,
                configuration: configuration
            )
            .clipShape(
                RoundedRectExt(
                    radius: Layout.cornerRadius,
                    corners: [.topLeft, .topRight]
                )
            )
        case let .content(content):
            NFTImageView(
                imageSource: content.imageSource,
                configuration: configuration
            )
            .overlay {
                if content.isSecureMode {
                    NFTCardSecureBlurView()
                }
            }
            .overlay(alignment: .topTrailing) {
                if content.isOnSale {
                    Image.TKUIKit.Icons.Size32.saleBadge
                        .resizable()
                        .frame(
                            width: Layout.saleBadgeSide,
                            height: Layout.saleBadgeSide
                        )
                        .shadow(color: .constantBlack.opacity(0.08), radius: 6, y: 2)
                }
            }
            .clipShape(
                RoundedRectExt(
                    radius: Layout.cornerRadius,
                    corners: [.topLeft, .topRight]
                )
            )
        }
    }

    @ViewBuilder
    var textArea: some View {
        switch config {
        case .shimmer:
            shimmerTextArea
        case let .content(content):
            VStack(alignment: .leading, spacing: 0) {
                Text(content.title)
                    .textStyle(.label2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                Text(content.subtitle)
                    .textStyle(.body3)
                    .foregroundStyle(content.subtitleColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Layout.textPadding)
            .frame(height: configuration.cardHeight - configuration.imageHeight)
        }
    }

    var shimmerTextArea: some View {
        VStack(alignment: .leading, spacing: Layout.shimmerTextSpacing) {
            shimmerTextBar(width: Layout.primaryShimmerTextWidth)
            shimmerTextBar(width: Layout.secondaryShimmerTextWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(Layout.textPadding)
        .frame(height: configuration.cardHeight - configuration.imageHeight)
    }

    func shimmerTextBar(width: CGFloat) -> some View {
        ShimmerSwiftUIView(
            config: ShimmerSwiftUIView.Config(
                color: .backgroundContentTint,
                cornerRadius: .value(Layout.shimmerTextCornerRadius)
            )
        )
        .frame(
            width: shimmerTextWidth(width),
            height: Layout.shimmerTextHeight
        )
    }

    func shimmerTextWidth(_ baseWidth: CGFloat) -> CGFloat {
        let availableWidth = max(
            1,
            configuration.cardWidth - Layout.textPadding.leading - Layout.textPadding.trailing
        )
        let scale = configuration.cardWidth / NFTImageView.Size.small.configuration.cardWidth
        return min(baseWidth * scale, availableWidth)
    }
}

private extension NFTCard {
    enum Layout {
        static let cornerRadius: CGFloat = 16
        static let textPadding = EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 12)
        static let shimmerTextSpacing: CGFloat = 4
        static let shimmerTextHeight: CGFloat = 12
        static let shimmerTextCornerRadius: CGFloat = 8
        static let primaryShimmerTextWidth: CGFloat = 65
        static let secondaryShimmerTextWidth: CGFloat = 90
        static let saleBadgeSide: CGFloat = 32
    }
}

private struct NFTCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tkTapAnimation(isPressed: configuration.isPressed)
    }
}

private struct NFTCardSecureBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> TKSecureBlurView {
        TKSecureBlurView()
    }

    func updateUIView(_ uiView: TKSecureBlurView, context: Context) {}
}

#Preview {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
            NFTCard(
                config: .content(
                    NFTCardContent(
                        id: "1",
                        title: "Plush Pepe",
                        subtitle: "Telegram User",
                        imageSource: .url(URL(string: "https://cryptologos.cc/logos/bitcoin-btc-logo.png?v=041"))
                    )
                ),
                action: {}
            )
            NFTCard(
                config: .shimmer,
                imageSize: .small
            )
            NFTCard(
                config: .content(
                    NFTCardContent(
                        id: "2",
                        title: "Snoop Dogg",
                        subtitle: "Anonymous",
                        subtitleColor: .accentOrange,
                        imageSource: .url(URL(string: "https://cryptologos.cc/logos/bitcoin-btc-logo.png?v=041")),
                        isSecureMode: true
                    )
                ),
                imageSize: .small,
                action: {}
            )
            NFTCard(
                config: .shimmer,
                configuration: NFTImageView.Configuration(
                    imageWidth: 140,
                    imageHeight: 140,
                    cardWidth: 140,
                    cardHeight: 196
                )
            )
        }
        .padding(16)
    }
    .tkImmediateButtonPresses()
    .background(TKPreview.palette.background.page)
    .debugPreview()
    .tkThemed()
}
