import Kingfisher
import SwiftUI
import UIKit

struct BannerItemModifier: ViewModifier {
    @Environment(\.tkPalette) private var palette

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .strokeBorder(palette.button.tertiaryBackground, lineWidth: Layout.borderWidth)
            )
            .contentShape(Rectangle())
    }

    enum Layout {
        static let cornerRadius: CGFloat = 20
        static let borderWidth: CGFloat = 1
    }
}

public extension View {
    func bannerItem() -> some View {
        modifier(BannerItemModifier())
    }
}

public struct BannerItemView: View {
    @Environment(\.tkPalette) private var palette
    @Environment(\.tkResolvedTheme) private var resolvedTheme
    @State private var isPressed = false

    let item: BannerItem
    let onTapDismiss: () -> Void
    let showsDismissButton: Bool
    let height: CGFloat
    let isTapEnabled: Bool

    public init(
        item: BannerItem,
        height: CGFloat,
        showsDismissButton: Bool = true,
        onTapDismiss: @escaping () -> Void = {},
        isTapEnabled: Bool = true
    ) {
        self.item = item
        self.height = height
        self.showsDismissButton = showsDismissButton
        self.onTapDismiss = onTapDismiss
        self.isTapEnabled = isTapEnabled
    }

    public var body: some View {
        Group {
            if let action = item.action {
                Button {
                    guard isTapEnabled else {
                        return
                    }
                    action()
                } label: {
                    bannerContent
                }
                .buttonStyle(BannerButtonStyle(isPressed: $isPressed))
                .accessibilityIdentifier("home_banner")
            } else {
                bannerContent
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(bannerBackgroundColor)
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            if showsDismissButton {
                closeButton
            }
        }
        .bannerItem()
        .tkTapAnimation(isPressed: isPressed)
    }

    private var bannerContent: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .textStyle(.label2)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(2)
                        .padding(.top, Layout.titleTopPadding)
                        .padding(.leading, Layout.titleLeadingPadding)
                    HStack(alignment: .top, spacing: 0) {
                        actionLabel
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, Layout.textImageSpacing)
                bannerImage(width: geometry.size.width * Layout.imageWidthRatio)
            }
            .frame(width: geometry.size.width, height: height, alignment: .top)
        }
        .frame(height: height)
    }

    private var closeButton: some View {
        Button {
            onTapDismiss()
        } label: {
            Image(uiImage: .TKUIKit.Icons.Size16.closeSmall)
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: Layout.closeIconSize,
                    height: Layout.closeIconSize
                )
                .foregroundStyle(.iconSecondary)
                .padding(Layout.closeIconPadding)
                .background(closeButtonBackgroundColor)
                .clipShape(Circle())
        }
        .padding(Layout.closeButtonPadding)
        .accessibilityIdentifier("home_banner_close")
    }

    @ViewBuilder
    private func bannerImage(width: CGFloat) -> some View {
        if let imageURL = item.imageURL {
            BannerRemoteImageView(url: imageURL, width: width, height: height)
        } else {
            defaultBannerImage(width: width)
        }
    }

    private var actionLabel: some View {
        actionLabelText
            .textStyle(.body3)
            .lineLimit(2)
            .padding(.top, Layout.subtitleTopPadding)
            .padding(.leading, Layout.subtitleLeadingPadding)
    }

    private var actionLabelText: Text {
        let description = Text(descriptionText)
            .foregroundColor(palette.text.primary.opacity(0.64))
        guard item.action != nil else { return description }
        return description
            + Text("\u{00A0}")
            .kerning(Layout.subtitleAccessoryLeadingAdjustment)
            + Text(Image(uiImage: .TKUIKit.Icons.Size12.chevronRight.withRenderingMode(.alwaysTemplate)))
            .baselineOffset(Layout.subtitleAccessoryBaselineOffset)
            .foregroundColor(palette.text.primary.opacity(0.64))
    }

    private var descriptionText: String {
        item.description.isEmpty ? item.actionTitle : item.description
    }

    private var bannerBackgroundColor: Color {
        switch resolvedTheme {
        case .light:
            palette.background.pageAlternate
        case .dark, .deepBlue:
            palette.background.page
        }
    }

    private var closeButtonBackgroundColor: Color {
        switch resolvedTheme {
        case .light:
            palette.background.contentAlternate
        case .dark, .deepBlue:
            palette.background.content
        }
    }

    private func defaultBannerImage(width: CGFloat) -> some View {
        Image(uiImage: .TKUIKit.Artwork.Banners.multichain)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }
}

extension BannerItemView {
    enum Layout {
        static let imageWidthRatio: CGFloat = 1.0 / 3.0
        // Banner is a fixed 90pt: 14 + 2 title lines (40) + 4 + 2 subtitle lines (32) fills it
        // exactly, so both texts can wrap without being clipped (matches the Figma spec).
        static let titleTopPadding: CGFloat = 13
        static let titleLeadingPadding: CGFloat = 16
        static let subtitleTopPadding: CGFloat = 2
        static let subtitleLeadingPadding: CGFloat = 16
        static let textImageSpacing: CGFloat = 8
        static let subtitleAccessoryLeadingAdjustment: CGFloat = -1
        static let subtitleAccessoryBaselineOffset: CGFloat = -2
        static let closeIconSize: CGFloat = 16
        static let closeIconPadding: CGFloat = 4
        static let closeButtonPadding: CGFloat = 10
    }
}

private struct BannerButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed = $0 }
    }
}

private struct BannerRemoteImageView: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat

    @State private var didFail = false

    var body: some View {
        Group {
            if didFail {
                fallbackImage
            } else {
                KFImage
                    .url(url)
                    .setProcessor(
                        DownsamplingImageProcessor(
                            size: CGSize(
                                width: max(width, 1) * UIScreen.main.scale,
                                height: max(height, 1) * UIScreen.main.scale
                            )
                        )
                    )
                    .loadDiskFileSynchronously()
                    .fade(duration: 0)
                    .placeholder {
                        ShimmerSwiftUIView(config: shimmerConfig)
                            .frame(width: width, height: height)
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
                    .frame(width: width, height: height)
                    .clipped()
            }
        }
        .id(url)
    }

    private var fallbackImage: some View {
        Image(uiImage: .TKUIKit.Artwork.Banners.multichain)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }

    private var shimmerConfig: ShimmerSwiftUIView.Config {
        ShimmerSwiftUIView.Config(color: .backgroundContentTint)
    }
}
