import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

public enum PerpsSearchMarketsState {
    case loading
    case loaded(items: [PerpsMarketRowItem], isLoadingNextPage: Bool)
    case empty
    case failed(String)
}

@MainActor
public protocol PerpsSearchViewModeling: ObservableObject {
    var searchText: String { get }
    var sort: PerpsMarketsSort { get }
    var filter: PerpsMarketFilter { get }
    var marketsState: PerpsSearchMarketsState { get }
    var isSearchFocusRequested: Bool { get }
    var onBack: (() -> Void)? { get }

    func onAppear()
    func onDisappear()
    func requestSearchFocus()
    func updateSearchText(_ value: String)
    func setSort(_ sort: PerpsMarketsSort)
    func setFilter(_ filter: PerpsMarketFilter)
    func selectMarket(_ id: Int64)
    func rowAppeared(_ id: Int64)
    func rowDisappeared(_ id: Int64)
    func retry()
}

public struct PerpsSearchView<ViewModel: PerpsSearchViewModeling>: View {
    @ObservedObject private var viewModel: ViewModel
    @FocusState private var isSearchFocused: Bool

    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: .push(
                    title: TKLocales.Perps.explore,
                    onBack: { viewModel.onBack?() }
                )
            )
            searchField
            filters
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
        .onChange(of: viewModel.isSearchFocusRequested) { isSearchFocused = $0 }
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

    var filters: some View {
        TabCategoriesView(
            items: PerpsMarketFilter.allCases.map { filter in
                TabCategoriesView.Item(
                    id: filter,
                    title: title(for: filter),
                    accessibilityIdentifier: "perps_search_filter_\(filter.rawValue)"
                )
            },
            initialSelection: viewModel.filter,
            onSelectionChange: viewModel.setFilter,
            style: .secondary,
            scrollToSelection: true
        )
    }

    func title(for filter: PerpsMarketFilter) -> String {
        switch filter {
        case .all: TKLocales.Trade.Assets.Categories.all
        case .tokens: TKLocales.Trade.Assets.Categories.tokens
        case .commodities: TKLocales.Perps.Search.Filters.commodities
        case .stocks: TKLocales.Trade.Assets.Categories.stocks
        case .etfs: TKLocales.Trade.Assets.Categories.etfs
        }
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
    static let scrollGestureDistance: CGFloat = 1
    static let interactivePlaceholderTopPadding: CGFloat = 30
    static let defaultPlaceholderTopPadding: CGFloat = 48
}
