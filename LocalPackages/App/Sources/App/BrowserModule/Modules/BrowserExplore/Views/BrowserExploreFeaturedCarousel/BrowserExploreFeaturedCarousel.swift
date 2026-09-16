import KeeperCore
import SwiftUI

struct BrowserExploreFeaturedCarousel: View {
    let apps: [PopularApp]
    let onSelect: (PopularApp) -> Void

    var body: some View {
        BrowserExploreFeaturedCarouselRepresentable(
            apps: apps,
            onSelect: onSelect
        )
        .frame(height: Layout.cardHeight)
    }

    enum Layout {
        static let cardHeight: CGFloat = 179
    }
}

private struct BrowserExploreFeaturedCarouselRepresentable: UIViewRepresentable {
    let apps: [PopularApp]
    let onSelect: (PopularApp) -> Void

    func makeUIView(context: Context) -> BrowserExploreFeaturedView {
        let view = BrowserExploreFeaturedView()
        view.didSelectPopularApp = onSelect
        return view
    }

    func updateUIView(_ uiView: BrowserExploreFeaturedView, context: Context) {
        uiView.didSelectPopularApp = onSelect
        uiView.dapps = apps
    }
}
