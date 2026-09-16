import SwiftUI
import UIKit

public enum ServiceCardConfig {
    case shimmer
    case content(ServiceCardContent)
}

public struct ServiceCardContent {
    var title: String
    var titleColor: TKColor
    var imageSource: AssetAvatarViewImageSource
    var changeConfiguration: ServiceCardCaptionConfig?
    var titleTag: TKTagSwiftUIViewConfig?
    var showsVerificationCheckmark: Bool

    public init(
        title: String,
        titleColor: TKColor = .textPrimary,
        imageSource: AssetAvatarViewImageSource,
        changeConfiguration: ServiceCardCaptionConfig? = nil,
        titleTag: TKTagSwiftUIViewConfig? = nil,
        showsVerificationCheckmark: Bool = false
    ) {
        self.title = title
        self.titleColor = titleColor
        self.imageSource = imageSource
        self.changeConfiguration = changeConfiguration
        self.titleTag = titleTag
        self.showsVerificationCheckmark = showsVerificationCheckmark
    }
}

public enum ServiceCardCaptionConfig {
    case shimmer
    case content(text: String, color: TKColor)
}

public struct ServiceCardView: View {
    let config: ServiceCardConfig
    let avatarSize: AssetAvatarView.Size
    let avatarShape: AssetAvatarView.Shape
    let textStyle: TKTextStyle
    private let height: CGFloat

    public init(
        config: ServiceCardConfig,
        avatarSize: AssetAvatarView.Size = .regular,
        avatarShape: AssetAvatarView.Shape = .circle,
        textStyle: TKTextStyle = .body3,
        height: CGFloat? = nil
    ) {
        self.config = config
        self.avatarSize = avatarSize
        self.avatarShape = avatarShape
        self.textStyle = textStyle
        self.height = height ?? Layout.height
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.contentSpacing) {
                avatarView
                captionView
            }
            .padding(.top, Layout.verticalPadding)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var captionView: some View {
        switch config {
        case .shimmer:
            VStack(spacing: 4) {
                ShimmerSwiftUIView(
                    config: ShimmerSwiftUIView.Config(
                        color: .backgroundContentTint,
                        cornerRadius: .capsule
                    )
                )
                .frame(width: 59, height: 12)
                .padding(.top, 2)
                ShimmerSwiftUIView(
                    config: ShimmerSwiftUIView.Config(
                        color: .backgroundContentTint,
                        cornerRadius: .capsule
                    )
                )
                .frame(width: 35, height: 12)
            }
        case let .content(content):
            VStack(spacing: Layout.captionSpacing) {
                HStack(spacing: Layout.titleIconSpacing) {
                    Text(content.title)
                        .textStyle(textStyle)
                        .foregroundStyle(content.titleColor)
                        .lineLimit(1)

                    if let titleTag = content.titleTag {
                        TKTagSwiftUIView(config: titleTag)
                    }

                    if content.showsVerificationCheckmark {
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.verification)
                            .renderingMode(.template)
                            .resizable()
                            .frame(
                                width: Layout.verificationIconSize,
                                height: Layout.verificationIconSize
                            )
                            .foregroundStyle(.accentBlue)
                    }
                }
                .frame(maxWidth: .infinity)

                if let changeConfiguration = content.changeConfiguration {
                    changeConfigurationView(changeConfiguration)
                }
            }
        }
    }

    @ViewBuilder
    private func changeConfigurationView(_ changeConfiguration: ServiceCardCaptionConfig) -> some View {
        switch changeConfiguration {
        case .shimmer:
            ShimmerSwiftUIView(
                config: ShimmerSwiftUIView.Config(
                    color: .backgroundContentTint,
                    cornerRadius: .capsule
                )
            )
            .frame(width: 35, height: 12)
        case let .content(changeText, changeColor):
            Text(changeText)
                .textStyle(textStyle)
                .foregroundStyle(changeColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
    }

    private var avatarView: some View {
        switch config {
        case .shimmer:
            AssetAvatarView(
                imageSource: .shimmer,
                size: avatarSize,
                shape: avatarShape
            )
        case let .content(content):
            AssetAvatarView(
                imageSource: content.imageSource,
                size: avatarSize,
                shape: avatarShape
            )
        }
    }
}

private extension ServiceCardView {
    enum Layout {
        static let captionSpacing: CGFloat = 1
        static let contentSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 2
        static let height: CGFloat = 113
        static let verticalPadding: CGFloat = 8
        static let titleIconSpacing: CGFloat = 2
        static let verificationIconSize: CGFloat = 12
    }
}

#Preview {
    HStack(spacing: 0) {
        Spacer()
        ServiceCardView(
            config: .content(
                ServiceCardContent(
                    title: "TON",
                    imageSource: .image(nil, chainIcon: nil),
                    changeConfiguration: .content(
                        text: "+ 1.23 %",
                        color: .accentGreen
                    )
                )
            )
        )
        ServiceCardView(
            config: .content(
                ServiceCardContent(
                    title: "TON",
                    imageSource: .image(nil, chainIcon: nil),
                    changeConfiguration: .shimmer
                )
            )
        )
        ServiceCardView(
            config: .shimmer
        )
        Spacer()
    }
    .debugPreview()
    .tkThemed()
}
