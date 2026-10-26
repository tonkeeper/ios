import Combine
import Perps
import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

enum TokenPickerV2RowContent {
    case skeleton
    case content(AssetBalanceRowCellContent)
}

struct TokenPickerV2RowView: View {
    let content: TokenPickerV2RowContent
    let showsDivider: Bool
    let action: (() -> Void)?

    var body: some View {
        AssetBalanceRowCell(
            config: cellConfig,
            showsDivider: showsDivider,
            action: action
        )
        .allowsHitTesting(isHitTestingEnabled)
    }
}

private extension TokenPickerV2RowView {
    var cellConfig: AssetBalanceRowCellConfig {
        switch content {
        case .skeleton:
            return .shimmer
        case let .content(content):
            return .content(content)
        }
    }

    var isHitTestingEnabled: Bool {
        switch content {
        case .skeleton:
            return false
        case .content:
            return true
        }
    }
}

struct TokenPickerV2HeaderView: View {
    @ObservedObject var viewModel: TokenPickerV2ViewModelImplementation
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: headerConfig
            )
            .fixedSize(horizontal: false, vertical: true)

            SearchField(
                insetsModifier: {
                    $0.top = 0
                    $0.bottom = 8
                },
                title: TKLocales.Trade.Search.placeholder,
                text: Binding(
                    get: { viewModel.searchText },
                    set: viewModel.search(text:)
                ),
                isFocused: $isSearchFocused,
                accessibilityIdentifier: "token_picker_search"
            )

            if viewModel.tabs.count > 1, viewModel.assetType != .perpetuals {
                TabCategoriesView(
                    items: viewModel.tabs.map { tab in
                        TabCategoriesView<TokenPickerV2ChainFilter>.Item(
                            id: tab.id,
                            title: tab.title,
                            image: tab.image,
                            isSelectable: tab.isSelectable,
                            accessibilityIdentifier: tab.id.accessibilityIdentifier
                        )
                    },
                    initialSelection: viewModel.selectedChainFilter,
                    onSelectionChange: { selection in
                        viewModel.selectChainFilter(selection)
                    },
                    style: .secondary
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension TokenPickerV2HeaderView {
    var headerConfig: DefaultModalCardHeader.Config {
        switch viewModel.headerStyle {
        case .modal:
            DefaultModalCardHeader.Config(
                leftIcon: viewModel.onBack.map { _ in
                    .back { _ in
                        viewModel.back()
                    }
                },
                title: DefaultModalCardHeader.Title(
                    text: viewModel.headerTitle
                ),
                rightIcon: .close(
                    onTap: { _ in
                        viewModel.close()
                    }
                )
            )
        case .push:
            if viewModel.onBack != nil {
                DefaultModalCardHeader.Config.push(
                    title: viewModel.headerTitle,
                    onBack: {
                        viewModel.back()
                    }
                )
            } else {
                DefaultModalCardHeader.Config(
                    title: DefaultModalCardHeader.Title(
                        text: viewModel.headerTitle
                    )
                )
            }
        }
    }
}

struct TokenPickerV2Screen: View {
    @ObservedObject var viewModel: TokenPickerV2ViewModelImplementation
    let ignoresSafeArea: Bool
    @Environment(\.tkPalette) private var palette

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TokenPickerV2HeaderView(viewModel: viewModel)

                if let queryViewModel = viewModel.currentQueryViewModel {
                    TokenPickerV2ContentView(
                        queryViewModel: queryViewModel,
                        searchText: viewModel.searchText,
                        showsCatalogSortControl: showsBottomControls,
                        listTitle: listTitle,
                        onSelectRow: viewModel.selectRow(_:)
                    )
                } else {
                    TokenPickerV2ContentView.skeleton(
                        showsCatalogSortControl: showsBottomControls,
                        palette: palette
                    )
                }
            }
            .background(.backgroundPage)

            if showsBottomControls {
                LinearGradient(
                    colors: [
                        palette.background.page.opacity(0),
                        palette.background.page,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: Layout.fadeHeight)
                HStack(spacing: Layout.controlsSpacing) {
                    if viewModel.showsCatalogSortControl {
                        TokenPickerV2MenuButton(
                            options: [.marketCap, .volume, .priceDiffDesc, .priceDiffAsc],
                            selected: viewModel.catalogSearchSort,
                            title: TokenPickerV2ViewModelImplementation.catalogSortTitle(for:),
                            onSelect: viewModel.selectCatalogSort
                        )
                    } else if viewModel.showsPerpsSortControl {
                        TokenPickerV2MenuButton(
                            options: PerpsMarketsSort.allCases,
                            selected: viewModel.perpsSearchSort,
                            title: \.title,
                            onSelect: viewModel.selectPerpsSort
                        )
                    }
                    if !viewModel.assetTypes.isEmpty {
                        TokenPickerV2MenuButton(
                            options: viewModel.assetTypes,
                            selected: viewModel.assetType,
                            title: \.title,
                            onSelect: viewModel.selectAssetType
                        )
                        .accessibilityIdentifier("token_picker_asset_type")
                    }
                }
                .padding(.bottom, Layout.bottomPadding)
            }
        }
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: ignoresSafeArea ? .all : .bottom)
    }

    private var showsBottomControls: Bool {
        viewModel.showsCatalogSortControl || viewModel.showsPerpsSortControl || !viewModel.assetTypes.isEmpty
    }

    private var listTitle: String? {
        viewModel.assetTypes.isEmpty ? nil : viewModel.assetType.title
    }

    private enum Layout {
        static let bottomPadding: CGFloat = 36
        static let controlsSpacing: CGFloat = 8
        static let fadeHeight: CGFloat = 68
    }
}

private struct TokenPickerV2ContentView: View {
    private enum Layout {
        static let skeletonRowCount = 8
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 24
        static let pageLoaderPadding: CGFloat = 16
        static let placeholderTopPadding: CGFloat = 32
        static let rowCornerRadius: CGFloat = 16
        static let catalogSortBottomInset: CGFloat = 64
        static let perpDividerLeadingInset: CGFloat = 16
    }

    @ObservedObject var queryViewModel: TokenPickerV2QueryViewModel
    let searchText: String
    let showsCatalogSortControl: Bool
    var listTitle: String?
    let onSelectRow: (String) -> Void
    @Environment(\.tkPalette) private var palette

    static func skeleton(
        showsCatalogSortControl: Bool,
        palette: TKPalette
    ) -> some View {
        rows(
            sections: [
                RowSection(
                    id: "skeleton",
                    title: nil,
                    items: (0 ..< Layout.skeletonRowCount).map(SkeletonRow.init)
                ),
            ],
            showsLoadingMore: false,
            showsCatalogSortControl: showsCatalogSortControl,
            palette: palette
        ) { index, total, _ in
            TokenPickerV2RowView(
                content: .skeleton,
                showsDivider: index < total - 1,
                action: nil
            )
        }
    }

    var body: some View {
        Group {
            let presentation = queryViewModel.presentation
            if presentation.showsSkeleton {
                Self.skeleton(
                    showsCatalogSortControl: showsCatalogSortControl,
                    palette: palette
                )
            } else if let placeholder = presentation.placeholder {
                placeholderView(placeholder)
            } else {
                Self.rows(
                    sections: sections(for: presentation.items),
                    showsLoadingMore: presentation.isLoadingMore,
                    showsCatalogSortControl: showsCatalogSortControl,
                    palette: palette
                ) { index, total, item in
                    tokenPickerRow(
                        item: item,
                        showsDivider: index < total - 1,
                        onSelect: { onSelectRow(item.id) }
                    )
                    .onAppear {
                        queryViewModel.loadNextPageIfNeeded(currentItem: item)
                    }
                }
            }
        }
        .onReceive(queryViewModel.$state.dropFirst()) { state in
            showToastIfNeeded(for: state)
        }
    }
}

private extension TokenPickerV2ContentView {
    struct SkeletonRow: Identifiable {
        let id: Int
    }

    struct RowSection<Item: Identifiable>: Identifiable {
        let id: String
        let title: String?
        let items: [Item]
    }

    func sections(
        for items: [TokenPickerV2QueryViewModel.Item]
    ) -> [RowSection<TokenPickerV2QueryViewModel.Item>] {
        let perpetuals = items.filter(\.isPerpetualMarket)
        guard queryViewModel.splitsPerpetualsIntoSections, !perpetuals.isEmpty else {
            return [RowSection(id: "items", title: listTitle, items: items)]
        }
        let tokens = items.filter { !$0.isPerpetualMarket }
        return [
            RowSection(id: "tokens", title: TKLocales.Trade.Assets.Categories.tokens, items: tokens),
            RowSection(id: "perpetuals", title: TKLocales.Perps.title, items: perpetuals),
        ].filter { !$0.items.isEmpty }
    }

    @ViewBuilder
    func tokenPickerRow(
        item: TokenPickerV2QueryViewModel.Item,
        showsDivider: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        switch item.payload {
        case let .asset(_, row):
            TokenPickerV2RowView(
                content: .content(row),
                showsDivider: showsDivider,
                action: onSelect
            )
        case let .perp(market):
            Button(action: onSelect) {
                PerpsMarketRowView(market: market)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay {
                if showsDivider {
                    VStack {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(.separatorCommon)
                            .frame(height: TKUIKit.Constants.separatorWidth)
                            .padding(.leading, Layout.perpDividerLeadingInset)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    static func rows<Item: Identifiable, Row: View>(
        sections: [RowSection<Item>],
        showsLoadingMore: Bool,
        showsCatalogSortControl: Bool,
        palette: TKPalette,
        @ViewBuilder row: @escaping (_ index: Int, _ total: Int, _ item: Item) -> Row
    ) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(sections) { section in
                    if let title = section.title {
                        ListTitleView(config: .text(title))
                    }
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        row(index, section.items.count, item)
                            .background(.backgroundContent)
                            .roundIfNeeded(
                                index: index,
                                total: section.items.count,
                                radius: Layout.rowCornerRadius
                            )
                    }
                }

                if showsLoadingMore {
                    CircularLoader(
                        mode: .indeterminate,
                        preset: .medium
                    )
                    .padding(.vertical, Layout.pageLoaderPadding)
                }
            }
            .padding(.bottom, Layout.bottomPadding)
            .padding(
                .bottom,
                showsCatalogSortControl
                    ? Layout.catalogSortBottomInset
                    : 0
            )
        }
        .tkImmediateButtonPresses()
        .padding(.horizontal, Layout.horizontalPadding)
        .background(.backgroundPage)
    }

    func placeholderView(
        _ placeholder: TokenPickerV2QueryViewModel.Placeholder
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                PlaceholderView(
                    config: placeholderConfig(for: placeholder)
                )
                Spacer(minLength: 0)
            }
            .padding(.top, Layout.placeholderTopPadding)
            .padding(.horizontal, Layout.horizontalPadding)
            .frame(maxWidth: .infinity)
        }
        .tkImmediateButtonPresses()
        .background(.backgroundPage)
    }

    func placeholderConfig(
        for placeholder: TokenPickerV2QueryViewModel.Placeholder
    ) -> PlaceholderView.Config {
        switch placeholder {
        case .empty:
            return PlaceholderView.Config(
                lottieResource: .magnifyingGlass,
                title: TKLocales.TokensPicker.Placeholder.notFoundTitle,
                subtitle: normalizedSearchText.map(
                    TKLocales.TokensPicker.Placeholder.noResultsSubtitle
                )
            )
        case let .error(message):
            return PlaceholderView.Config(
                lottieResource: .exclamationmarkCircle,
                title: TKLocales.TokensPicker.Placeholder.errorTitle,
                subtitle: message ?? TKLocales.TokensPicker.Placeholder.errorSubtitle,
                button: PlaceholderView.ButtonConfig(
                    title: TKLocales.Actions.retry,
                    icon: .TKUIKit.Icons.Size16.refresh,
                    action: retry
                )
            )
        }
    }

    var normalizedSearchText: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func retry() {
        Task {
            await queryViewModel.refresh()
        }
    }

    func showToastIfNeeded(for state: TokenPickerV2QueryViewModel.State) {
        guard case let .failed(rowData, message) = state,
              !rowData.items.isEmpty
        else {
            return
        }

        ToastPresenter.showToast(
            configuration: .defaultConfiguration(
                text: message ?? TKLocales.Trade.Assets.Errors.load
            )
        )
    }
}

private struct TokenPickerV2MenuButton<Option: Equatable>: View {
    let options: [Option]
    let selected: Option
    let title: (Option) -> String
    let onSelect: (Option) -> Void
    @State private var anchorView: UIView?

    var body: some View {
        ButtonView(
            config: ButtonView.Config(
                title: title(selected),
                size: .small,
                appearance: .tertiary,
                icon: ButtonView.Icon(
                    image: .TKUIKit.Icons.Size16.switch,
                    alignment: .trailing
                ),
                action: showMenu
            )
        )
        .background(
            AnchorViewResolver { view in
                anchorView = view
            }
        )
    }

    func showMenu() {
        guard let anchorView else {
            return
        }

        TKPopupMenuController.show(
            sourceView: anchorView,
            position: .top,
            minimumWidth: 200,
            items: options.enumerated().map { index, option in
                TKPopupMenuItem(
                    title: title(option),
                    hasSeparator: index + 1 < options.count,
                    selectionHandler: { onSelect(option) }
                )
            },
            isSelectable: true,
            selectedIndex: options.firstIndex(of: selected)
        )
    }
}
