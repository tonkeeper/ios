import SwiftUI

public struct ListTitleViewPreviews: View {
    @Environment(\.tkPalette) private var palette

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                ListTitleView(
                    config: .text("Title")
                )
                .padding(.horizontal, Layout.rowHorizontalPadding)
                .background(.backgroundContent)

                ListTitleView(
                    config: .text(
                        "Title",
                        accessory: .init(
                            title: "See all",
                            action: {}
                        )
                    )
                )
                .padding(.horizontal, Layout.rowHorizontalPadding)
                .background(.backgroundContent)

                ListTitleView(
                    config: .text(
                        "Title",
                        titleAction: {}
                    )
                )
                .padding(.horizontal, Layout.rowHorizontalPadding)
                .background(.backgroundContent)

                ListTitleView(
                    config: .shimmer(hasAccessory: true)
                )
                .padding(.horizontal, Layout.rowHorizontalPadding)
                .background(.backgroundContent)

                ListTitleView(
                    config: .shimmer(hasAccessory: false)
                )
                .padding(.horizontal, Layout.rowHorizontalPadding)
                .background(.backgroundContent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }
}

private extension ListTitleViewPreviews {
    enum Layout {
        static let sectionSpacing: CGFloat = 24
        static let rowHorizontalPadding: CGFloat = 16
    }
}

#Preview {
    ListTitleViewPreviews()
        .debugPreview(background: .page)
        .tkThemed()
}
