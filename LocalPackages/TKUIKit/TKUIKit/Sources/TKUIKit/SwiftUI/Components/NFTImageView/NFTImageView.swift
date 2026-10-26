import SwiftUI
import UIKit

public enum NFTImageViewImageSource: Sendable, Equatable {
    case url(URL?)
    case image(UIImage?)
    case shimmer
}

public struct NFTImageView: View {
    public enum Size: Sendable {
        case small
        case medium
    }

    public struct Configuration: Sendable, Equatable {
        public let imageWidth: CGFloat
        public let imageHeight: CGFloat
        public let cardWidth: CGFloat
        public let cardHeight: CGFloat

        public init(
            imageWidth: CGFloat,
            imageHeight: CGFloat,
            cardWidth: CGFloat,
            cardHeight: CGFloat
        ) {
            self.imageWidth = imageWidth
            self.imageHeight = imageHeight
            self.cardWidth = cardWidth
            self.cardHeight = cardHeight
        }
    }

    private let imageSource: NFTImageViewImageSource
    private let configuration: Configuration

    public init(
        imageSource: NFTImageViewImageSource,
        size: Size = .medium
    ) {
        self.imageSource = imageSource
        self.configuration = size.configuration
    }

    public init(
        imageSource: NFTImageViewImageSource,
        configuration: Configuration
    ) {
        self.imageSource = imageSource
        self.configuration = configuration
    }

    public var body: some View {
        contentView
            .frame(width: configuration.imageWidth, height: configuration.imageHeight)
            .clipped()
    }

    @ViewBuilder
    private var contentView: some View {
        switch imageSource {
        case let .url(url):
            if let url {
                TKRemoteImage(
                    url: url,
                    downsampleSize: CGSize(width: configuration.imageWidth, height: configuration.imageHeight)
                ) {
                    ShimmerSwiftUIView(config: shimmerConfig())
                } failure: {
                    EmptyView()
                }
            }
        case let .image(image):
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        case .shimmer:
            ShimmerSwiftUIView(config: shimmerConfig())
        }
    }
}

public extension NFTImageView.Size {
    var configuration: NFTImageView.Configuration {
        switch self {
        case .small:
            NFTImageView.Configuration(
                imageWidth: 114,
                imageHeight: 114,
                cardWidth: 114,
                cardHeight: 166
            )
        case .medium:
            NFTImageView.Configuration(
                imageWidth: 171,
                imageHeight: 171,
                cardWidth: 171,
                cardHeight: 237
            )
        }
    }
}

private func shimmerConfig() -> ShimmerSwiftUIView.Config {
    ShimmerSwiftUIView.Config(color: .backgroundContentTint)
}

#Preview {
    HStack(spacing: 12) {
        NFTImageView(
            imageSource: .url(URL(string: "https://cryptologos.cc/logos/bitcoin-btc-logo.png?v=041")),
            size: .small
        )
        .background(TKPreview.palette.background.contentTint)

        NFTImageView(
            imageSource: .image(.TKUIKit.Icons.Size44.placeholder),
            size: .medium
        )
        .background(TKPreview.palette.background.contentTint)

        NFTImageView(
            imageSource: .shimmer,
            size: .medium
        )
        .background(TKPreview.palette.background.contentTint)
    }
    .debugPreview()
}
