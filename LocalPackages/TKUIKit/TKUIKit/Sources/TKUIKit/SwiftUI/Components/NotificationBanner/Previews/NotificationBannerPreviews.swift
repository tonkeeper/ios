import SwiftUI

public struct NotificationBannerPreviews: View {
    @Environment(\.tkPalette) private var palette

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Layout.bannerSpacing) {
                ForEach(NotificationBanner.State.allCases, id: \.self) { state in
                    NotificationBanner(
                        content: NotificationBannerContent(
                            title: "Title",
                            description: "Description",
                            state: state,
                            buttonTitle: "Button",
                            showsCloseButton: true
                        )
                    )
                    NotificationBanner(
                        content: NotificationBannerContent(
                            title: "Title",
                            description: "Description",
                            state: state,
                            buttonTitle: "Button",
                            showsCloseButton: false
                        )
                    )
                    NotificationBanner(
                        content: NotificationBannerContent(
                            title: "Title",
                            description: "Description",
                            state: state,
                            showsCloseButton: false
                        )
                    )
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }
}

private extension NotificationBannerPreviews {
    enum Layout {
        static let bannerSpacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
    }
}

#Preview {
    NotificationBannerPreviews()
        .debugPreview(background: .page)
        .tkThemed()
}
