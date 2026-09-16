import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsSearchView: View {
    @ObservedObject var viewModel: PerpsSearchViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: .push(
                    title: TKLocales.Perps.explore,
                    onBack: { viewModel.onBack?() }
                )
            )
            searchField
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .overlay(alignment: .bottom) {
            PerpsSortMenuButton(
                sort: viewModel.sort,
                menuPosition: .top,
                onSelect: viewModel.setSort
            )
            .padding(.vertical, Layout.sortPillVerticalPadding)
            .frame(maxWidth: .infinity)
            .tkScrim(.backgroundPage, edge: .bottom)
        }
        .task {
            try? await Task.sleep(nanoseconds: Layout.autoFocusDelayNanoseconds)
            isSearchFocused = true
        }
    }
}

private extension PerpsSearchView {
    var searchField: some View {
        SearchField(
            insetsModifier: { insets in
                insets.top = 0
                insets.bottom = Layout.searchFieldBottomPadding
            },
            title: TKLocales.Perps.Search.placeholder,
            text: Binding(
                get: { viewModel.searchText },
                set: viewModel.updateSearchText
            ),
            isFocused: $isSearchFocused
        )
    }

    @ViewBuilder
    var content: some View {
        switch viewModel.marketsState {
        case .loading:
            VStack {
                Spacer()
                CircularLoader(mode: .indeterminate, preset: .medium)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            placeholder(
                config: PlaceholderView.Config(
                    lottieResource: .exclamationmarkCircle,
                    title: TKLocales.Perps.Search.errorTitle,
                    subtitle: message,
                    button: .init(
                        title: TKLocales.Actions.retry,
                        icon: .TKUIKit.Icons.Size16.refresh,
                        action: viewModel.retry
                    )
                )
            )
        case .empty:
            placeholder(
                config: PlaceholderView.Config(
                    lottieResource: .magnifyingGlass,
                    title: TKLocales.Perps.Search.emptyTitle,
                    subtitle: emptySubtitle
                )
            )
        case let .loaded(markets, isLoadingNextPage):
            ScrollView(showsIndicators: false) {
                PerpsMarketRowsCard(
                    markets: markets,
                    isLoadingNextPage: isLoadingNextPage,
                    onSelect: viewModel.selectMarket,
                    onRowAppear: viewModel.rowAppeared,
                    onRowDisappear: viewModel.rowDisappeared
                )
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, Layout.listBottomPadding)
            }
            .tkImmediateButtonPresses()
            .simultaneousGesture(
                DragGesture(minimumDistance: Layout.scrollGestureDistance)
                    .onChanged { _ in isSearchFocused = false }
            )
        }
    }

    func placeholder(config: PlaceholderView.Config) -> some View {
        VStack(spacing: 0) {
            PlaceholderView(config: config)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(
            .top,
            config.button == nil
                ? Layout.defaultPlaceholderTopPadding
                : Layout.interactivePlaceholderTopPadding
        )
    }

    var emptySubtitle: String {
        let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return TKLocales.Perps.Search.emptySubtitle
        }
        return TKLocales.Perps.Search.emptySubtitleForQuery(trimmed)
    }
}

private enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let searchFieldBottomPadding: CGFloat = 8
    static let listBottomPadding: CGFloat = 80
    static let sortPillVerticalPadding: CGFloat = 16
    static let autoFocusDelayNanoseconds: UInt64 = 150_000_000
    static let scrollGestureDistance: CGFloat = 1
    static let interactivePlaceholderTopPadding: CGFloat = 30
    static let defaultPlaceholderTopPadding: CGFloat = 48
}
