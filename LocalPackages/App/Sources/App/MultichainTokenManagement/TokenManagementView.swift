import AppUI
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct TokenManagementScreen: View {
    @ObservedObject var viewModel: TokenManagementViewModelImplementation
    @State private var isFiltersPresented = false
    @Environment(\.tkPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            TokenManagementHeaderView(
                viewModel: viewModel,
                onFiltersTap: { isFiltersPresented = true }
            )

            if let queryViewModel = viewModel.currentQueryViewModel {
                TokenManagementScreenContentView(
                    queryViewModel: queryViewModel,
                    searchText: viewModel.searchText,
                    hiddenItemIDs: viewModel.hiddenItemIDs,
                    onToggleVisibility: viewModel.toggleVisibility(for:),
                    onRetry: viewModel.retryLoadingAssets
                )
            } else {
                TokenManagementScreenContentView.skeleton(background: palette.background.page)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isSaveButtonVisible {
                TokenManagementSaveFooterView(
                    action: viewModel.saveChanges
                )
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .tkBottomSheet(
            isPresented: $isFiltersPresented,
            header: { dismiss in
                TKBottomSheetHeaderConfiguration(
                    title: .title(title: TKLocales.Filters.title),
                    rightButton: .close(action: { _ in dismiss() })
                )
            },
            content: {
                TokenManagementFiltersSheet(viewModel: viewModel)
            }
        )
    }
}

private struct TokenManagementFiltersSheet: View {
    @ObservedObject var viewModel: TokenManagementViewModelImplementation

    var body: some View {
        FilterToggleView(
            items: [
                FilterToggleItem(
                    title: TKLocales.Filters.Balances.hideDust,
                    subtitle: TKLocales.Filters.Balances.hideDustCaption,
                    isOn: viewModel.hidesDustBalances,
                    onToggle: viewModel.setHidesDustBalances
                ),
            ]
        )
    }
}

private struct TokenManagementHeaderView: View {
    @ObservedObject var viewModel: TokenManagementViewModelImplementation
    let onFiltersTap: () -> Void
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    leftIcon: DefaultModalCardHeader.Icon(
                        image: .TKUIKit.Icons.Size16.sliders,
                        size: 16,
                        padding: 8,
                        accessibilityIdentifier: "token_management_filters_button",
                        onTap: { _ in onFiltersTap() }
                    ),
                    title: DefaultModalCardHeader.Title(
                        text: TKLocales.TokenManagement.title
                    ),
                    rightIcon: .close(
                        onTap: { _ in
                            viewModel.close()
                        }
                    ),
                    height: .compact
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            SearchField(
                insetsModifier: {
                    $0.bottom = 8
                },
                title: TKLocales.Trade.Search.placeholder,
                text: Binding(
                    get: { viewModel.searchText },
                    set: viewModel.updateSearchText
                ),
                isFocused: $isSearchFocused
            )

            if !viewModel.categories.isEmpty {
                TabCategoriesView(
                    items: viewModel.categories.map { category in
                        TabCategoriesView<String>.Item(
                            id: category.id,
                            title: category.title,
                            image: category.icon
                        )
                    },
                    initialSelection: viewModel.selectedCategoryID,
                    onSelectionChange: viewModel.selectCategory,
                    style: .secondary
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private struct TokenManagementScreenContentView: View {
    private enum Layout {
        static let skeletonRowCount = 8
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 24
        static let placeholderTopPadding: CGFloat = 32
        static let pageLoaderPadding: CGFloat = 16
    }

    @ObservedObject var queryViewModel: TokenManagementQueryViewModel
    let searchText: String
    let hiddenItemIDs: Set<String>
    let onToggleVisibility: (String) -> Void
    let onRetry: () -> Void
    @Environment(\.tkPalette) private var palette

    static func skeleton(background: Color) -> some View {
        rows(
            content: (0 ..< Layout.skeletonRowCount).map(SkeletonRow.init),
            showsLoadingMore: false,
            background: background
        ) { index, _ in
            TokenManagementItemRowView(
                config: .shimmer,
                showDivider: index < Layout.skeletonRowCount - 1
            )
        }
    }

    var body: some View {
        Group {
            let presentation = queryViewModel.presentation
            if presentation.showsSkeleton {
                Self.skeleton(background: palette.background.page)
            } else if let placeholder = presentation.placeholder {
                placeholderView(placeholder)
            } else {
                Self.rows(
                    content: presentation.items,
                    showsLoadingMore: presentation.isLoadingMore,
                    background: palette.background.page
                ) { index, item in
                    TokenManagementItemRowView(
                        item: item,
                        isHidden: hiddenItemIDs.contains(item.id),
                        showDivider: index < presentation.items.count - 1,
                        onToggleVisibility: {
                            onToggleVisibility(item.id)
                        }
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

private extension TokenManagementScreenContentView {
    struct SkeletonRow: Identifiable {
        let id: Int
    }

    static func rows<Item: Identifiable, Row: View>(
        content: [Item],
        showsLoadingMore: Bool,
        background: Color,
        @ViewBuilder row: @escaping (_ index: Int, _ item: Item) -> Row
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(content.enumerated()), id: \.element.id) { index, item in
                        row(index, item)
                    }
                }
                .asCellsGroup()

                if showsLoadingMore {
                    CircularLoader(
                        mode: .indeterminate,
                        preset: .medium
                    )
                    .padding(.vertical, Layout.pageLoaderPadding)
                }
            }
            .padding(.bottom, Layout.bottomPadding)
        }
        .tkImmediateButtonPresses()
        .background(background)
    }

    func placeholderView(
        _ placeholder: TokenManagementQueryViewModel.Placeholder
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
        for placeholder: TokenManagementQueryViewModel.Placeholder
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
                    action: onRetry
                )
            )
        }
    }

    var normalizedSearchText: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func showToastIfNeeded(for state: TokenManagementQueryViewModel.State) {
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

private struct TokenManagementSaveFooterView: View {
    let action: () -> Void

    var body: some View {
        ButtonView(
            config: ButtonView.Config(
                title: TKLocales.TokenManagement.saveChanges,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: action
            )
        )
        .padding(.top, Layout.verticalPadding)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.verticalPadding)
        .background(.backgroundPage.opacity(Layout.backgroundOpacity))
    }
}

private extension TokenManagementSaveFooterView {
    enum Layout {
        static let backgroundOpacity = 0.96
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
    }
}
