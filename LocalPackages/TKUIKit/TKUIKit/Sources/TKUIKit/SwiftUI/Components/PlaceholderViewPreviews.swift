import SwiftUI

public struct PlaceholderViewPreviews: View {
    @Environment(\.tkPalette) private var palette

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Layout.sectionSpacing) {
                previewCard(config: notFoundConfig)
                previewCard(config: errorConfig)
                previewCard(config: staticImage)
            }
            .padding(.horizontal, Layout.contentHorizontalPadding)
            .padding(.vertical, Layout.contentVerticalPadding)
            .frame(maxWidth: .infinity)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }
}

private extension PlaceholderViewPreviews {
    enum Layout {
        static let sectionSpacing: CGFloat = 16
        static let contentHorizontalPadding: CGFloat = 16
        static let contentVerticalPadding: CGFloat = 24
        static let cardHorizontalPadding: CGFloat = 16
        static let defaultCardTopPadding: CGFloat = 48
        static let interactiveCardTopPadding: CGFloat = 30
        static let cardBottomPadding: CGFloat = 32
        static let cardMinHeight: CGFloat = 220
        static let cardCornerRadius: CGFloat = 16
    }

    var notFoundConfig: PlaceholderView.Config {
        PlaceholderView.Config(
            lottieResource: .magnifyingGlass,
            title: "Not Found",
            subtitle: "There were no results for 'TON'."
        )
    }

    var errorConfig: PlaceholderView.Config {
        PlaceholderView.Config(
            lottieResource: .exclamationmarkCircle,
            title: "Something went wrong",
            subtitle: "We couldn't load content.",
            button: PlaceholderView.ButtonConfig(
                title: "Retry",
                icon: .TKUIKit.Icons.Size16.refresh,
                action: {}
            )
        )
    }

    var staticImage: PlaceholderView.Config {
        PlaceholderView.Config(
            image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
            title: "Static Image",
            subtitle: "We couldn't load content.",
            button: PlaceholderView.ButtonConfig(
                title: "Retry",
                icon: .TKUIKit.Icons.Size16.refresh,
                action: {}
            )
        )
    }

    func previewCard(config: PlaceholderView.Config) -> some View {
        PlaceholderView(config: config)
            .padding(.horizontal, Layout.cardHorizontalPadding)
            .padding(
                .top,
                config.button == nil
                    ? Layout.defaultCardTopPadding
                    : Layout.interactiveCardTopPadding
            )
            .padding(.bottom, Layout.cardBottomPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: Layout.cardMinHeight,
                alignment: .top
            )
            .background(.backgroundContent)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Layout.cardCornerRadius,
                    style: .continuous
                )
            )
    }
}

#Preview {
    PlaceholderViewPreviews()
        .debugPreview(background: .page)
        .tkThemed()
}
