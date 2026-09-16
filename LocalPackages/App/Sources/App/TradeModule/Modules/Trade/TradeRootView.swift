import SwiftUI
import TKLocalize
import TKLogging
import TKUIKit

struct TradeRootView: View {
    @Environment(\.tkPalette) private var palette
    private enum ScrollAnchor {
        static let top = "trade-root-top-anchor"
    }

    @ObservedObject var viewModel: TradeViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                palette.background.page
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    searchField

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .id(ScrollAnchor.top)

                            TradeRaffleBannerView(viewModel: viewModel)

                            if !viewModel.services.isEmpty {
                                TradeServicesView(
                                    services: viewModel.services,
                                    onOpenService: { service in
                                        viewModel.openService(service)
                                    }
                                )
                            }

                            VStack(alignment: .center, spacing: Layout.shelfSpacing) {
                                if !viewModel.perpsShelfMarkets.isEmpty {
                                    TradePerpsShelfView(
                                        markets: viewModel.perpsShelfMarkets,
                                        onOpenShelf: viewModel.openPerps,
                                        onOpenMarket: viewModel.openPerpsMarket
                                    )
                                }

                                if !viewModel.favoriteAssets.isEmpty {
                                    TradeFavoritesSectionView(
                                        items: viewModel.visibleFavoriteAssets,
                                        isEditing: viewModel.isFavoritesEditing,
                                        onOpenAsset: { item in
                                            viewModel.openFavorite(item)
                                        },
                                        onToggleEditing: {
                                            viewModel.toggleFavoritesEditing()
                                        },
                                        onRemove: { item in
                                            viewModel.removeFavorite(item)
                                        }
                                    )
                                }

                                if isShimmerState {
                                    ForEach(skeletonContent) { item in
                                        TradeShelfView(
                                            content: item.content
                                        )
                                    }
                                } else {
                                    if shelves.isEmpty {
                                        emptyStateView
                                    } else {
                                        ForEach(shelves) { shelf in
                                            TradeShelfView(
                                                content: .content(
                                                    shelf: shelf,
                                                    onOpenSeeAll: { grid in
                                                        viewModel.openSeeAll(for: grid)
                                                    },
                                                    onOpenAsset: { item in
                                                        viewModel.openAsset(item)
                                                    }
                                                ),
                                                multichainEnabled: viewModel.multichainEnabled,
                                                selectedGroupID: viewModel.selectedGroupID(for: shelf),
                                                selectedGridID: viewModel.selectedGridID(for: shelf),
                                                onSelectGroup: { groupID in
                                                    viewModel.selectGroup(id: groupID, for: shelf)
                                                },
                                                onSelectGrid: { gridID in
                                                    viewModel.selectGrid(id: gridID, for: shelf)
                                                }
                                            )
                                            .id(shelf.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, Layout.bottomPadding)
                    }
                    .tkImmediateButtonPresses()
                    .refreshable {
                        await Task {
                            await MinimumRefreshDurationBehavior.perform {
                                await viewModel.refresh()
                            }
                        }.value
                    }
                }
                .onChange(of: viewModel.scrollToTopRequestID) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                    }
                }
                .onChange(of: viewModel.scrollToShelfRequest) { request in
                    guard let request else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(request.shelfID, anchor: .top)
                    }
                }
            }
        }
    }

    struct SkeletonContentItem: Identifiable {
        var id: Int
        var content: TradeShelfViewContent
    }

    @ViewBuilder
    private var searchField: some View {
        if isShimmerState {
            searchFieldContent
        } else {
            Button(action: viewModel.openSearch) {
                searchFieldContent
            }
            .buttonStyle(.plain)
        }
    }

    private var searchFieldContent: some View {
        SearchField(
            insetsModifier: {
                $0.bottom = 8
            },
            title: TKLocales.Trade.Search.placeholder,
            text: .constant(""),
            allowsTextInput: false,
            shimmer: isShimmerState
        )
    }

    private var skeletonContent: [SkeletonContentItem] {
        (0 ..< Layout.skeletonShelvesCount)
            .map {
                SkeletonContentItem(
                    id: $0,
                    content: .skeleton(
                        hasHeader: false,
                        itemsCount: Layout.skeletonItemsCount
                    )
                )
            }
    }

    private var isShimmerState: Bool {
        switch viewModel.state {
        case let .pending(data), let .refreshing(data, task: _):
            data.shelves.isEmpty
        case .loaded, .failed:
            false
        }
    }

    private var shelves: [TradeShelfViewData] {
        viewModel.state.data.shelves
    }
}

private extension TradeRootView {
    var emptyStateView: some View {
        VStack(spacing: 0) {
            PlaceholderView(
                config: PlaceholderView.Config(
                    lottieResource: .exclamationmarkCircle,
                    title: TKLocales.Trade.Placeholder.errorTitle,
                    subtitle: TKLocales.Trade.Placeholder.errorSubtitle,
                    button: PlaceholderView.ButtonConfig(
                        title: TKLocales.Actions.retry,
                        icon: .TKUIKit.Icons.Size16.refresh,
                        action: retry
                    )
                )
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, Layout.screenPadding)
        .padding(.top, Layout.emptyStateTopPadding)
    }

    func retry() {
        Task {
            await viewModel.refresh()
        }
    }
}

private extension TradeRootView {
    enum Layout {
        static let bottomPadding: CGFloat = 20
        static let emptyStateTopPadding: CGFloat = 30
        static let screenPadding: CGFloat = 16
        static let shelfSpacing: CGFloat = 16
        static let skeletonItemsCount: Int = 8
        static let skeletonShelvesCount: Int = 3
    }
}
