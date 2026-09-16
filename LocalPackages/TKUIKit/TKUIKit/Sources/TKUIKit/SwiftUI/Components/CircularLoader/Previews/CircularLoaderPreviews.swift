import SwiftUI

public struct CircularLoaderPreviews: View {
    @Environment(\.tkPalette) private var palette

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                previewRow(title: "xSmall") {
                    HStack(spacing: Layout.itemSpacing) {
                        CircularLoader(
                            preset: .xSmall,
                            duration: 8,
                            restartToken: 0
                        )

                        CircularLoader(
                            mode: .indeterminate,
                            preset: .xSmall
                        )
                    }
                }

                previewRow(title: "small") {
                    HStack(spacing: Layout.itemSpacing) {
                        CircularLoader(
                            preset: .small,
                            duration: 8,
                            restartToken: 0
                        )

                        CircularLoader(
                            mode: .indeterminate,
                            preset: .small
                        )
                    }
                }

                previewRow(title: "medium") {
                    HStack(spacing: Layout.itemSpacing) {
                        CircularLoader(
                            preset: .medium,
                            duration: 8,
                            restartToken: 0
                        )

                        CircularLoader(
                            mode: .indeterminate,
                            preset: .medium
                        )
                    }
                }
            }
            .padding(.vertical, Layout.contentVerticalPadding)
            .padding(.horizontal, Layout.contentHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }

    private func previewRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)

            content()
                .frame(maxWidth: .infinity, minHeight: Layout.previewHeight)
                .background(.backgroundContent)
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        }
    }
}

private extension CircularLoaderPreviews {
    enum Layout {
        static let contentVerticalPadding: CGFloat = 24
        static let contentHorizontalPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let rowSpacing: CGFloat = 12
        static let itemSpacing: CGFloat = 18
        static let previewHeight: CGFloat = 72
        static let cornerRadius: CGFloat = 16
    }
}

#Preview {
    CircularLoaderPreviews()
        .debugPreview(background: .page)
        .tkThemed()
}
