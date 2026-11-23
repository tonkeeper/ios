import SwiftUI
import TKUIKit

struct TradeRaffleBannerView: View {
    @ObservedObject var viewModel: TradeViewModel
    @State private var isRendered: Bool
    @State private var isExpanded: Bool

    init(viewModel: TradeViewModel) {
        self.viewModel = viewModel
        _isRendered = State(initialValue: Self.isVisible(viewModel))
        _isExpanded = State(initialValue: Self.isVisible(viewModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            if isRendered {
                BannerView(
                    items: items,
                    onDismiss: { item, _ in viewModel.dismissRaffleBanner(id: item.id) }
                )
                .id(items.map(\.id))
                .padding(.top, Layout.topPadding)
                .frame(height: Layout.sectionHeight, alignment: .top)
                .opacity(isExpanded ? 1 : 0)
                .offset(y: isExpanded ? 0 : -Layout.collapseOffset)
                .allowsHitTesting(isExpanded)
            }
        }
        .frame(height: isExpanded ? Layout.sectionHeight : 0, alignment: .top)
        .clipped()
        .onAppear {
            guard isExpanded else { return }
            viewModel.raffleBannerDidAppear()
        }
        .onChange(of: isVisible) { isVisible in
            updateVisibility(isVisible)
        }
        .onChange(of: isExpanded) { isExpanded in
            guard isExpanded else { return }
            viewModel.raffleBannerDidAppear()
        }
    }

    private var isVisible: Bool {
        Self.isVisible(viewModel)
    }

    private var items: [BannerItem] {
        viewModel.raffleBanners.compactMap { presentation in
            guard let banner = presentation.raffle.banner else { return nil }
            return BannerItem(
                id: presentation.raffle.id,
                title: banner.title,
                description: banner.button.title.isEmpty ? (banner.description ?? "") : banner.button.title,
                actionTitle: banner.button.title,
                imageURL: URL(string: banner.imageURL),
                action: { viewModel.openRaffle(id: presentation.raffle.id, presentedFromBanner: true) }
            )
        }
    }

    private func updateVisibility(_ isVisible: Bool) {
        if isVisible {
            guard !isExpanded else { return }
            isRendered = true
            DispatchQueue.main.async {
                guard self.isVisible else { return }
                withAnimation(Layout.animation) {
                    isExpanded = true
                }
            }
        } else {
            guard isRendered || isExpanded else { return }
            withAnimation(Layout.animation) {
                isExpanded = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Layout.animationDuration) {
                guard !self.isVisible else { return }
                isRendered = false
            }
        }
    }

    private static func isVisible(_ viewModel: TradeViewModel) -> Bool {
        !viewModel.raffleBanners.isEmpty
    }

    private enum Layout {
        static let bannerHeight: CGFloat = 90
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 16
        static let collapseOffset: CGFloat = 8
        static let animationDuration: TimeInterval = 0.2
        static let animation = Animation.easeInOut(duration: animationDuration)
        static let sectionHeight = topPadding + bannerHeight + bottomPadding
    }
}
