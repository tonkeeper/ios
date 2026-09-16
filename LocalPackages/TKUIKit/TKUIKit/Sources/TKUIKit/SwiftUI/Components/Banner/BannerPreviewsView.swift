import SwiftUI

struct BannerPreviewsView: View {
    @Environment(\.tkPalette) private var palette
    @State private var singlePreviewID = UUID()
    @State private var stackPreviewID = UUID()
    @State private var customPreviewID = UUID()
    @State private var isSinglePreviewVisible = true
    @State private var isStackPreviewVisible = true
    @State private var isCustomPreviewVisible = true

    init() {}

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                section(
                    title: "Single",
                    description: "One banner. Close hides it.",
                    resetAction: {
                        isSinglePreviewVisible = true
                        singlePreviewID = UUID()
                    }
                ) {
                    if isSinglePreviewVisible {
                        BannerView(
                            items: [singleBannerItem]
                        )
                        .id(singlePreviewID)
                    }
                }

                section(
                    title: "Stack",
                    description: "Close shows the next banner in the stack.",
                    resetAction: {
                        isStackPreviewVisible = true
                        stackPreviewID = UUID()
                    }
                ) {
                    if isStackPreviewVisible {
                        BannerView(
                            items: stackBannerItems
                        )
                        .id(stackPreviewID)
                    }
                }

                section(
                    title: "Custom",
                    description: "Remote artwork and description from API.",
                    resetAction: {
                        isCustomPreviewVisible = true
                        customPreviewID = UUID()
                    }
                ) {
                    if isCustomPreviewVisible {
                        BannerView(
                            items: [customBannerItem]
                        )
                        .id(customPreviewID)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }
}

private extension BannerPreviewsView {
    func section<Content: View>(
        title: String,
        description: String,
        resetAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)

                    Text(description)
                        .textStyle(.body3)
                        .foregroundStyle(.textSecondary)
                }

                Spacer(minLength: 0)

                Button(action: resetAction) {
                    Text("Reset")
                        .textStyle(.body3)
                        .foregroundStyle(.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.backgroundContent)
                        )
                }
                .buttonStyle(BannerPreviewResetButtonStyle())
            }
            .padding(.horizontal, 16)

            content()
        }
    }

    var singleBannerItem: BannerItem {
        BannerItem(
            title: "Get started with your\nwallet — learn step by step",
            actionTitle: "Start Now",
            action: {}
        )
    }

    var customBannerItem: BannerItem {
        BannerItem(
            id: "banner-custom",
            title: "Boost rewards with Keeper Battery",
            description: "Top up once and cover network fees automatically",
            actionTitle: "Open",
            imageURL: URL(string: "https://picsum.photos/seed/tonkeeper-banner/800/400"),
            action: {}
        )
    }

    var stackBannerItems: [BannerItem] {
        Array([
            BannerItem(
                id: "banner-stack-1",
                title: "Get started with your\nwallet — learn step by step",
                actionTitle: "Start Now",
                action: {}
            ),
            BannerItem(
                id: "banner-stack-2",
                title: "Set up backup and keep recovery phrase safe",
                actionTitle: "Review Guide",
                action: {}
            ),
            BannerItem(
                id: "banner-stack-3",
                title: "Explore multichain receive addresses in one place",
                actionTitle: "Open Details",
                imageURL: URL(string: "https://picsum.photos/seed/tonkeeper-banner/800/400"),
                action: {}
            ),
        ].reversed())
    }
}

private struct BannerPreviewResetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.14), value: configuration.isPressed)
    }
}

#Preview {
    BannerPreviewsView()
        .tkThemed()
}
