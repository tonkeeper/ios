import AppUI
import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct MultichainHistoryView: View {
    @ObservedObject var viewModel: MultichainHistoryViewModelImplementation
    let onClose: (() -> Void)?
    let onOpenTransaction: (URL, String?) -> Void
    @State private var selectedActivity: MultichainActivity?
    @State private var isFiltersPresented = false
    @Environment(\.tkPalette) private var palette

    init(
        viewModel: MultichainHistoryViewModelImplementation,
        onClose: (() -> Void)? = nil,
        onOpenTransaction: @escaping (URL, String?) -> Void = { _, _ in }
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.onOpenTransaction = onOpenTransaction
    }

    var body: some View {
        ZStack {
            palette.background.page
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                chainTabs
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                typeFilterActionBar
            }
        }
        .tkBottomSheet(
            item: $selectedActivity,
            header: { _, _ in .compact },
            content: { activity in
                MultichainTransactionDetailsView(
                    model: viewModel.transactionDetailsModel(for: activity),
                    onOpenTransaction: onOpenTransaction,
                    onCopy: { Pasteboard.copy(value: $0) }
                )
            }
        )
        .tkBottomSheet(
            isPresented: $isFiltersPresented,
            header: { dismiss in
                TKBottomSheetHeaderConfiguration(
                    title: .title(title: TKLocales.Filters.title),
                    rightButton: .close(action: { _ in dismiss() })
                )
            },
            content: {
                FiltersSheet(viewModel: viewModel)
            }
        )
        .task {
            viewModel.viewDidLoad()
        }
        .onDisappear {
            viewModel.disappeared()
        }
    }
}

private extension MultichainHistoryView {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: onClose.map { onClose in
                    DefaultModalCardHeader.Icon(
                        image: .TKUIKit.Icons.Size16.chevronLeft,
                        size: 16,
                        padding: 8,
                        accessibilityIdentifier: "history_back_button",
                        onTap: { _ in onClose() }
                    )
                },
                title: DefaultModalCardHeader.Title(
                    text: TKLocales.History.title
                ),
                rightIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.sliders,
                    size: 16,
                    padding: 8,
                    accessibilityIdentifier: "history_filters_button",
                    onTap: { _ in isFiltersPresented = true }
                )
            )
        )
    }

    @ViewBuilder
    var chainTabs: some View {
        if !viewModel.chainTabs.isEmpty {
            TabCategoriesView(
                items: viewModel.chainTabs.map { tab in
                    TabCategoriesView<MultichainHistoryChainFilter>.Item(
                        id: tab.id,
                        title: tab.title,
                        image: tab.image,
                        isSelectable: tab.isSelectable
                    )
                },
                initialSelection: viewModel.selectedChainFilter,
                onSelectionChange: { selection in
                    viewModel.selectChainFilter(selection)
                },
                style: .secondary,
                insetsModifier: { insets in
                    insets.leading = Layout.tabsHorizontalPadding
                    insets.trailing = Layout.tabsHorizontalPadding
                    insets.bottom = Layout.tabsBottomPadding
                }
            )
            .frame(height: Layout.tabsHeight)
        }
    }

    @ViewBuilder
    var content: some View {
        if viewModel.contentDescriptors.isEmpty {
            MultichainHistorySkeletonView()
        } else {
            ZStack {
                ForEach(viewModel.contentDescriptors) { descriptor in
                    MultichainHistoryContentView(
                        viewModel: descriptor.queryViewModel,
                        onSelectActivity: selectActivity,
                        isActive: descriptor.isActive
                    )
                    .opacity(descriptor.isActive ? 1 : 0)
                    .allowsHitTesting(descriptor.isActive)
                    .accessibilityHidden(!descriptor.isActive)
                    .id(descriptor.id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    var typeFilterActionBar: some View {
        if let queryViewModel = viewModel.currentQueryViewModel {
            TypeFilterActionBar(
                viewModel: viewModel,
                queryViewModel: queryViewModel
            )
        }
    }

    func selectActivity(_ activity: MultichainActivity) {
        selectedActivity = activity
    }

    struct FiltersSheet: View {
        @ObservedObject var viewModel: MultichainHistoryViewModelImplementation

        var body: some View {
            FilterToggleView(
                items: [
                    FilterToggleItem(
                        title: TKLocales.Filters.History.hideDust,
                        subtitle: TKLocales.Filters.History.hideDustCaption,
                        isOn: viewModel.hidesDustTransactions,
                        onToggle: viewModel.setHidesDustTransactions
                    ),
                ]
            )
        }
    }

    struct TypeFilterActionBar: View {
        @ObservedObject var viewModel: MultichainHistoryViewModelImplementation
        @ObservedObject var queryViewModel: MultichainHistoryQueryViewModel
        @State private var typeFilterButtonAnchorView: UIView?
        @Environment(\.tkPalette) private var palette

        var body: some View {
            if viewModel.isTypeFilterActionBarVisible(for: queryViewModel) {
                VStack(spacing: 0) {
                    ButtonView(
                        config: ButtonView.Config(
                            title: viewModel.selectedTypeFilterTitle,
                            size: .small,
                            appearance: .tertiary,
                            icon: ButtonView.Icon(
                                image: .TKUIKit.Icons.Size16.switch,
                                alignment: .trailing
                            ),
                            action: showTypeFilterMenu
                        )
                    )
                    .background(
                        AnchorViewResolver { view in
                            typeFilterButtonAnchorView = view
                        }
                    )
                    .padding(.top, Layout.typeFilterActionBarTopPadding)
                    .padding(.bottom, Layout.typeFilterActionBarBottomPadding)
                }
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(
                                color: palette.background.page.opacity(0),
                                location: 0
                            ),
                            Gradient.Stop(
                                color: palette.background.page,
                                location: 1
                            ),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }

        func showTypeFilterMenu() {
            guard let sourceView = typeFilterButtonAnchorView else {
                return
            }

            let items = viewModel.typeFilterItems
            TKPopupMenuController.show(
                sourceView: sourceView,
                position: .top,
                minimumWidth: Layout.typeFilterPopupWidth,
                items: items.enumerated().map { index, item in
                    TKPopupMenuItem(
                        title: item.title,
                        hasSeparator: index + 1 < items.count,
                        selectionHandler: {
                            viewModel.selectTypeFilter(item.id)
                        }
                    )
                },
                selectedIndex: items.firstIndex(where: \.isSelected)
            )
        }
    }

    enum Layout {
        static let tabsHeight: CGFloat = 56
        static let tabsHorizontalPadding: CGFloat = 16
        static let tabsBottomPadding: CGFloat = 16
        static let typeFilterActionBarTopPadding: CGFloat = 32
        static let typeFilterActionBarBottomPadding: CGFloat = 8
        static let typeFilterPopupWidth: CGFloat = 180
    }
}

private struct MultichainHistoryContentView: View {
    @ObservedObject var viewModel: MultichainHistoryQueryViewModel
    let onSelectActivity: (MultichainActivity) -> Void
    let isActive: Bool

    var body: some View {
        let presentation = viewModel.presentation

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if presentation.showsSkeleton {
                    MultichainHistorySkeletonView()
                } else if let placeholder = presentation.placeholder {
                    placeholderView(placeholder)
                } else {
                    sectionsView(presentation.sections)
                    if presentation.isLoadingMore {
                        loadingMoreView
                    }
                }
            }
        }
        .tkImmediateButtonPresses()
        .refreshable {
            await Task {
                await MinimumRefreshDurationBehavior.perform {
                    await viewModel.refresh()
                }
            }.value
        }
        .onAppear {
            guard isActive else {
                return
            }
            viewModel.appeared()
        }
    }
}

private extension MultichainHistoryContentView {
    func sectionsView(_ sections: [MultichainHistorySection]) -> some View {
        ForEach(sections) { section in
            Section {
                ForEach(Array(section.groups.enumerated()), id: \.element.id) { index, group in
                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            MultichainHistoryTransactionCell(
                                item: item,
                                showsDivider: index < group.items.count - 1
                            ) {
                                onSelectActivity(item.activity)
                            }
                            .onAppear {
                                guard isActive else {
                                    return
                                }
                                viewModel.loadNextPageIfNeeded(currentItem: item)
                            }
                        }
                    }
                    .asCellsGroup()
                    .padding(.top, index == 0 ? 0 : Layout.cellSpacing)
                }

                Spacer()
                    .frame(height: Layout.sectionSpacing)
            } header: {
                ListTitleView(
                    config: .text(section.title)
                )
                .padding(.horizontal, Layout.horizontalPadding)
            }
        }
    }

    func placeholderView(_ placeholder: MultichainHistoryQueryViewModel.Placeholder) -> some View {
        VStack(spacing: 0) {
            PlaceholderView(
                config: placeholderConfig(placeholder)
            )
            Spacer(minLength: 0)
        }
        .padding(.top, Layout.placeholderTopPadding)
        .frame(maxWidth: .infinity)
    }

    func placeholderConfig(_ placeholder: MultichainHistoryQueryViewModel.Placeholder) -> PlaceholderView.Config {
        switch placeholder {
        case .empty:
            return PlaceholderView.Config(
                lottieResource: .clock,
                title: TKLocales.MultichainHistory.Placeholder.title,
                subtitle: TKLocales.MultichainHistory.Placeholder.subtitle,
                button: PlaceholderView.ButtonConfig(
                    title: TKLocales.MultichainHistory.Placeholder.Buttons.addFunds,
                    action: viewModel.addFunds
                )
            )
        case .filtered:
            return PlaceholderView.Config(
                lottieResource: .clock,
                title: TKLocales.MultichainHistory.Placeholder.Filtered.title,
                subtitle: TKLocales.MultichainHistory.Placeholder.Filtered.subtitle
            )
        case let .error(message):
            return PlaceholderView.Config(
                lottieResource: .exclamationmarkCircle,
                title: TKLocales.Trade.Placeholder.errorTitle,
                subtitle: message ?? TKLocales.Trade.Placeholder.errorSubtitle,
                button: PlaceholderView.ButtonConfig(
                    title: TKLocales.Actions.retry,
                    icon: .TKUIKit.Icons.Size16.refresh,
                    action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                )
            )
        }
    }

    var loadingMoreView: some View {
        CircularLoader(
            mode: .indeterminate,
            preset: .medium
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, Layout.loadingMorePadding)
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cellSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 16
        static let placeholderTopPadding: CGFloat = 139
        static let loadingMorePadding: CGFloat = 16
    }
}

private struct MultichainHistorySkeletonView: View {
    private let rows = Array(0 ..< 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .shimmer(hasAccessory: false))
                .padding(.horizontal, Layout.horizontalPadding)

            LazyVStack(spacing: Layout.cellSpacing) {
                ForEach(rows, id: \.self) { _ in
                    TransactionCell(config: .shimmer)
                        .asCellsGroup()
                }
            }
        }
    }
}

private extension MultichainHistorySkeletonView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cellSpacing: CGFloat = 8
    }
}
