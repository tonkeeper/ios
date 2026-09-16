import SwiftUI

/// The assets shelf card: rounded background that morphs its height to follow the
/// content's natural height, clipping content to the animated bounds. Pair with
/// `ShelfCrossfadeView` inside so the asset sets fade while the card resizes.
///
/// The height is driven by explicitly animated state (not a transaction), so sibling
/// views below the card follow the resize without the caller wrapping state changes
/// in `withAnimation`.
public struct ShelfTransitionCardView<Content: View>: View {
    private let configuration: ShelfTransitionConfiguration
    private let content: () -> Content

    @State private var height: CGFloat?

    public init(
        configuration: ShelfTransitionConfiguration = .default,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.configuration = configuration
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.top, Layout.topPadding)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ContentHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .frame(height: height, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .fill(.backgroundContent)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            )
            .onPreferenceChange(ContentHeightPreferenceKey.self) { contentHeight in
                updateHeight(contentHeight)
            }
    }

    private func updateHeight(_ contentHeight: CGFloat?) {
        guard let contentHeight else { return }
        guard let height else {
            height = contentHeight
            return
        }
        guard abs(height - contentHeight) > 0.5 else { return }
        withAnimation(configuration.heightAnimation) {
            self.height = contentHeight
        }
    }
}

private enum Layout {
    static let cornerRadius: CGFloat = 16
    static let topPadding: CGFloat = 8
}

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat? {
        nil
    }

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}
