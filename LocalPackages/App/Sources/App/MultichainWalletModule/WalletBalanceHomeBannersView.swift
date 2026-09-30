import SwiftUI
import TKUIKit

struct WalletBalanceHomeBannersView: View {
    @ObservedObject var viewModel: WalletBalanceHomeBannersViewModel
    @State private var isRendered: Bool
    @State private var isExpanded: Bool
    @State private var sectionHeight: CGFloat

    init(viewModel: WalletBalanceHomeBannersViewModel) {
        self.viewModel = viewModel
        _isRendered = State(initialValue: viewModel.isSectionVisible)
        _isExpanded = State(initialValue: viewModel.isSectionVisible)
        _sectionHeight = State(initialValue: viewModel.sectionHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isRendered {
                WalletBalanceHomeBannersContentView(viewModel: viewModel, isContentVisible: isExpanded)
                    .frame(height: sectionHeight, alignment: .top)
                    .opacity(isExpanded ? 1 : 0)
                    .offset(y: isExpanded ? 0 : -Layout.collapseOffset)
                    .allowsHitTesting(isExpanded)
            }
        }
        .frame(height: isExpanded ? sectionHeight : 0, alignment: .top)
        .clipped()
        .onChange(of: viewModel.sectionHeight) { sectionHeight in
            updateSectionHeight(sectionHeight)
        }
        .onChange(of: viewModel.isSectionVisible) { isVisible in
            updateSectionVisibility(isVisible)
        }
    }

    private func updateSectionHeight(_ sectionHeight: CGFloat) {
        guard self.sectionHeight != sectionHeight else { return }
        withAnimation(Layout.animation) {
            self.sectionHeight = sectionHeight
        }
    }

    private func updateSectionVisibility(_ isVisible: Bool) {
        if isVisible {
            guard !isExpanded else { return }
            isRendered = true
            DispatchQueue.main.async {
                guard viewModel.isSectionVisible else { return }
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
                guard !viewModel.isSectionVisible else { return }
                isRendered = false
            }
        }
    }
}

struct WalletBalanceHomeBannersUIKitView: View {
    @ObservedObject var viewModel: WalletBalanceHomeBannersViewModel

    var body: some View {
        WalletBalanceHomeBannersContentView(viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct WalletBalanceHomeBannersContentView: View {
    @ObservedObject var viewModel: WalletBalanceHomeBannersViewModel
    /// Whether the deck is actually on screen. Path 1 mounts the deck
    /// collapsed (opacity 0, height 0) and animates it in a runloop later, so
    /// the impression must wait until it is genuinely visible.
    var isContentVisible: Bool = true

    var body: some View {
        WalletBalanceHomeBannersDeckView(viewModel: viewModel, isContentVisible: isContentVisible)
            .onDisappear {
                viewModel.handleBannersDisappeared()
            }
    }
}

private struct WalletBalanceHomeBannersDeckView: View {
    @ObservedObject var viewModel: WalletBalanceHomeBannersViewModel
    let isContentVisible: Bool

    /// Latest front-banner id reported by `BannerView` while not yet visible;
    /// flushed once `isContentVisible` becomes true.
    @State private var deferredShownID: String?

    var body: some View {
        BannerView(
            items: viewModel.state.items,
            onDismiss: { item, remainingCount in
                viewModel.dismissBanner(item, remainingCount: remainingCount)
            },
            onItemShown: { item in
                guard isContentVisible else {
                    deferredShownID = item.id
                    return
                }
                viewModel.handleBannerShown(id: item.id)
            }
        )
        .id(viewModel.state.items.map(\.id))
        .onChange(of: isContentVisible) { isVisible in
            guard isVisible, let id = deferredShownID else { return }
            deferredShownID = nil
            viewModel.handleBannerShown(id: id)
        }
    }
}

private extension WalletBalanceHomeBannersView {
    typealias Layout = WalletBalanceHomeBannersLayout
}

enum WalletBalanceHomeBannersLayout {
    static let singleHeight: CGFloat = 106
    static let expandedHeight: CGFloat = 116
    static let collapseOffset: CGFloat = 8
    static let animationDuration: TimeInterval = 0.2
    static let animation: Animation = .easeInOut(duration: animationDuration)

    static func height(remainingCount: Int) -> CGFloat {
        if remainingCount <= 0 {
            return 0
        }

        if remainingCount == 1 {
            return singleHeight
        }

        return expandedHeight
    }
}
