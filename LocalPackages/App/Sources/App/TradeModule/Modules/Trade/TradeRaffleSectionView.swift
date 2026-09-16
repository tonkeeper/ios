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
            if isRendered, let raffle = viewModel.rafflePresentation, let banner = raffle.raffle.banner {
                BannerItemView(
                    item: BannerItem(
                        id: raffle.raffle.id,
                        title: banner.title,
                        description: banner.button.title.isEmpty ? (banner.description ?? "") : banner.button.title,
                        actionTitle: banner.button.title,
                        imageURL: URL(string: banner.imageURL),
                        action: { viewModel.openRaffle() }
                    ),
                    height: Layout.bannerHeight,
                    onTapDismiss: { viewModel.dismissRaffleBanner() }
                )
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, Layout.topPadding)
                .padding(.bottom, Layout.bottomPadding)
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
        viewModel.rafflePresentation?.shouldShowTradeBanner == true
    }

    private enum Layout {
        static let bannerHeight: CGFloat = 90
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 16
        static let screenPadding: CGFloat = 16
        static let collapseOffset: CGFloat = 8
        static let animationDuration: TimeInterval = 0.2
        static let animation = Animation.easeInOut(duration: animationDuration)
        static let sectionHeight = topPadding + bannerHeight + bottomPadding
    }
}
