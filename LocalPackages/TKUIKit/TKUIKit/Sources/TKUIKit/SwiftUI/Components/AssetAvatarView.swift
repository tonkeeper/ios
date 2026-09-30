import Kingfisher
import SwiftUI

public enum AssetAvatarViewImageSource: Sendable, Equatable {
    case url(URL?, chainIcon: UIImage? = nil)
    case image(UIImage?, chainIcon: UIImage? = nil)
    case shimmer

    var chainIcon: UIImage? {
        switch self {
        case let .url(_, chainIcon):
            chainIcon
        case let .image(_, chainIcon):
            chainIcon
        case .shimmer:
            nil
        }
    }
}

public enum ChainIconPosition: Sendable {
    case leading
    case trailing
}

public struct AssetAvatarView: View {
    public enum Size: Sendable, Hashable {
        case extraSmall
        case small
        case regular
        case dapp
        case large
        case extraLarge
    }

    public enum Shape: Sendable, Hashable {
        case circle
        case rectangle(cornerRadius: CGFloat = 0)
    }

    public struct Configuration: Sendable, Equatable {
        public let imageSize: CGFloat
        public let chainIconSize: CGFloat
        public let chainIconPadding: CGFloat
        public let chainIconOffsetX: CGFloat
        public let chainIconOffsetY: CGFloat

        public init(
            imageSize: CGFloat,
            chainIconSize: CGFloat,
            chainIconPadding: CGFloat,
            chainIconOffsetX: CGFloat,
            chainIconOffsetY: CGFloat
        ) {
            self.imageSize = imageSize
            self.chainIconSize = chainIconSize
            self.chainIconPadding = chainIconPadding
            self.chainIconOffsetX = chainIconOffsetX
            self.chainIconOffsetY = chainIconOffsetY
        }
    }

    let imageSource: AssetAvatarViewImageSource
    let configuration: Configuration
    let shape: Shape
    let chainIconPosition: ChainIconPosition
    let chainIconBackgroundColor: Color
    let imageBackgroundColor: TKColor

    public init(
        imageSource: AssetAvatarViewImageSource,
        size: Size? = nil,
        shape: Shape? = nil,
        chainIconPosition: ChainIconPosition? = nil,
        chainIconBackgroundColor: Color? = nil,
        imageBackgroundColor: TKColor = .backgroundContentTint
    ) {
        self.init(
            imageSource: imageSource,
            configuration: (size ?? .small).configuration,
            shape: shape,
            chainIconPosition: chainIconPosition,
            chainIconBackgroundColor: chainIconBackgroundColor,
            imageBackgroundColor: imageBackgroundColor
        )
    }

    public init(
        imageSource: AssetAvatarViewImageSource,
        configuration: Configuration,
        shape: Shape? = nil,
        chainIconPosition: ChainIconPosition? = nil,
        chainIconBackgroundColor: Color? = nil,
        imageBackgroundColor: TKColor = .backgroundContentTint
    ) {
        self.imageSource = imageSource
        self.configuration = configuration
        self.shape = shape ?? .circle
        self.chainIconPosition = chainIconPosition ?? .trailing
        self.chainIconBackgroundColor = chainIconBackgroundColor ?? .clear
        self.imageBackgroundColor = imageBackgroundColor
    }

    struct AvatarShape: SwiftUI.Shape {
        var shape: AssetAvatarView.Shape

        nonisolated func path(in rect: CGRect) -> Path {
            switch shape {
            case .circle:
                Path(UIBezierPath(ovalIn: rect).cgPath)
            case let .rectangle(cornerRadius):
                Path(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
            }
        }
    }

    struct ChainIconShape: SwiftUI.Shape {
        var chainIconPosition: ChainIconPosition
        var configuration: Configuration

        nonisolated func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(rect: rect)
            path.append(UIBezierPath(ovalIn: cutoutRect(in: rect)).reversing())
            return Path(path.cgPath)
        }

        private nonisolated func cutoutRect(in rect: CGRect) -> CGRect {
            let chainIconSize = configuration.chainIconSize
            let cutoutDiameter = (chainIconSize + configuration.chainIconPadding * 2)

            switch chainIconPosition {
            case .leading:
                return CGRect(
                    x: rect.minX - configuration.chainIconOffsetX - configuration.chainIconPadding,
                    y: rect.maxY - cutoutDiameter + configuration.chainIconOffsetY + configuration.chainIconPadding,
                    width: cutoutDiameter,
                    height: cutoutDiameter
                )
            case .trailing:
                return CGRect(
                    x: rect.maxX - cutoutDiameter + configuration.chainIconOffsetX + configuration.chainIconPadding,
                    y: rect.maxY - cutoutDiameter + configuration.chainIconOffsetY + configuration.chainIconPadding,
                    width: cutoutDiameter,
                    height: cutoutDiameter
                )
            }
        }
    }

    private var size: CGFloat {
        configuration.imageSize
    }

    public var body: some View {
        ZStack {
            clippedContentView
            if let chainIcon = imageSource.chainIcon {
                let chainIconSize = configuration.chainIconSize
                Image(uiImage: chainIcon)
                    .resizable()
                    .frame(width: chainIconSize, height: chainIconSize)
                    .foregroundStyle(.iconPrimary)
                    .background(chainIconBackgroundColor)
                    .clipShape(Circle())
                    .offset(
                        x: {
                            switch chainIconPosition {
                            case .leading:
                                (chainIconSize - size) / 2 - configuration.chainIconOffsetX
                            case .trailing:
                                (size - chainIconSize) / 2 + configuration.chainIconOffsetX
                            }
                        }(),
                        y: (size - chainIconSize) / 2 + configuration.chainIconOffsetY
                    )
            }
        }
    }

    @ViewBuilder
    private var clippedContentView: some View {
        let avatarContentView = contentView
            .clipShape(AvatarShape(shape: shape))

        if imageSource.chainIcon != nil {
            avatarContentView
                .clipShape(
                    ChainIconShape(
                        chainIconPosition: chainIconPosition,
                        configuration: configuration
                    )
                )
        } else {
            avatarContentView
        }
    }

    private var contentView: some View {
        AssetAvatarContentView(imageSource: imageSource, size: size)
            .frame(width: size, height: size)
            .background(imageBackgroundColor)
    }
}

struct AssetAvatarContentView: View {
    let imageSource: AssetAvatarViewImageSource
    let size: CGFloat

    var body: some View {
        switch imageSource {
        case let .url(url, _):
            if let url {
                URLAvatarImageView(
                    url: url,
                    size: size
                )
            } else {
                Self.imageContentView(
                    for: .TKUIKit.Icons.Size44.placeholder,
                    size: size
                )
            }
        case let .image(image, _):
            Self.imageContentView(
                for: image ?? .TKUIKit.Icons.Size44.placeholder,
                size: size
            )
        case .shimmer:
            ShimmerSwiftUIView(config: shimmerConfig())
        }
    }

    private struct URLAvatarImageView: View {
        let url: URL
        let size: CGFloat

        @State private var didFail = false

        var body: some View {
            let iconSource = DappIconSource(url: url)
            Group {
                if didFail {
                    imageContentView(
                        for: .TKUIKit.Icons.Size44.placeholder,
                        size: size
                    )
                } else {
                    KFImage
                        .source(iconSource.source)
                        .alternativeSources(iconSource.alternativeSources)
                        .setProcessor(
                            DownsamplingImageProcessor(
                                size: CGSize(
                                    width: size * UIScreen.main.scale,
                                    height: size * UIScreen.main.scale
                                )
                            )
                        )
                        .loadDiskFileSynchronously()
                        .fade(duration: 0)
                        .placeholder {
                            ShimmerSwiftUIView(config: shimmerConfig())
                        }
                        .onSuccess { _ in
                            didFail = false
                        }
                        .onFailure { _ in
                            didFail = true
                        }
                        .cancelOnDisappear(true)
                        .resizable()
                        .scaledToFill()
                }
            }
        }
    }

    fileprivate static func imageContentView(
        for image: UIImage,
        size: CGFloat
    ) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

extension AssetAvatarView.Size {
    var configuration: AssetAvatarView.Configuration {
        switch self {
        case .extraSmall:
            AssetAvatarView.Configuration(
                imageSize: 24,
                chainIconSize: 12,
                chainIconPadding: 1.5,
                chainIconOffsetX: 2,
                chainIconOffsetY: 2
            )
        case .small:
            AssetAvatarView.Configuration(
                imageSize: 44,
                chainIconSize: 18,
                chainIconPadding: 2,
                chainIconOffsetX: 4,
                chainIconOffsetY: 4
            )
        case .regular:
            AssetAvatarView.Configuration(
                imageSize: 56,
                chainIconSize: 20,
                chainIconPadding: 2,
                chainIconOffsetX: 4,
                chainIconOffsetY: 4
            )
        case .dapp:
            AssetAvatarView.Configuration(
                imageSize: 64,
                chainIconSize: 20,
                chainIconPadding: 2,
                chainIconOffsetX: 4,
                chainIconOffsetY: 4
            )
        case .large:
            AssetAvatarView.Configuration(
                imageSize: 72,
                chainIconSize: 24,
                chainIconPadding: 4,
                chainIconOffsetX: -4,
                chainIconOffsetY: 4
            )
        case .extraLarge:
            AssetAvatarView.Configuration(
                imageSize: 96,
                chainIconSize: 32,
                chainIconPadding: 4,
                chainIconOffsetX: 4,
                chainIconOffsetY: 4
            )
        }
    }
}

private func shimmerConfig() -> ShimmerSwiftUIView.Config {
    ShimmerSwiftUIView.Config(color: .backgroundContentTint)
}

private var sampleShapes: [AssetAvatarView.Shape] {
    [.circle, .rectangle(cornerRadius: 12)]
}

private var sampleSizesAndColors: [(AssetAvatarView.Size, Color)] {
    [
        (.extraSmall, .red),
        (.small, .green),
        (.regular, .brown),
        (.large, .cyan),
        (.extraLarge, .yellow),
    ]
}

#Preview {
    VStack(spacing: 24) {
        HStack {
            ForEach(sampleShapes, id: \.self) { shape in
                AssetAvatarView(
                    imageSource: .url(URL(string: "https://avatars.githubusercontent.com/u/88587596")!),
                    shape: shape
                )
            }
        }
        HStack {
            ForEach(sampleShapes, id: \.self) { shape in
                AssetAvatarView(
                    imageSource: .url(nil, chainIcon: .TKUIKit.Icons.Size20.tonChain),
                    shape: shape,
                    chainIconPosition: .leading
                )
            }
        }
        HStack {
            ForEach(sampleShapes, id: \.self) { shape in
                AssetAvatarView(
                    imageSource: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.tonChain),
                    shape: shape
                )
            }
        }
        HStack {
            ForEach(sampleShapes, id: \.self) { shape in
                AssetAvatarView(
                    imageSource: .shimmer,
                    shape: shape
                )
            }
        }
        VStack {
            ForEach(sampleShapes, id: \.self) { shape in
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(sampleSizesAndColors, id: \.0) { size, color in
                        AssetAvatarView(
                            imageSource: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.qrCodeSmall),
                            size: size,
                            shape: shape,
                            chainIconBackgroundColor: color
                        )
                    }
                }
            }
            SwapPairAvatarView(
                left: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.tonChain),
                right: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.tonChain)
            )
            .padding(.top, 24)
        }
    }
    .debugPreview()
}
