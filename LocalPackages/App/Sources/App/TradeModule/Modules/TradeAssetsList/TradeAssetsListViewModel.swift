import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class TradeAssetsListViewModel: ObservableObject {
    private enum Constants {
        static let searchDebounceNanoseconds: UInt64 = 300_000_000
    }

    @Published private(set) var searchText = ""
    @Published private(set) var selectedCategory: TradingAssetCategory
    @Published private(set) var currentQueryViewModel: TradeAssetsListQueryViewModel

    let categories = TradingAssetCategory.allCases

    private let categoryViewModels: [TradingAssetCategory: TradeAssetsListCategoryViewModel]
    private let analyticsProvider: AnalyticsProvider
    private let analyticsSource: TradeFlowAnalyticsSource
    private let onBack: () -> Void
    private let onOpenAssetDetails: (TradingAsset) -> Void

    private var activateQueryTask: Task<Void, Never>?
    private var hasLoaded = false
    private var hasDisappeared = false

    init(
        analyticsProvider: AnalyticsProvider,
        analyticsSource: TradeFlowAnalyticsSource,
        assetsListService: TradingAssetsListService,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter,
        selectedCategory: TradingAssetCategory,
        onBack: @escaping () -> Void,
        onOpenAssetDetails: @escaping (TradingAsset) -> Void
    ) {
        self.analyticsProvider = analyticsProvider
        self.analyticsSource = analyticsSource
        self.selectedCategory = selectedCategory
        self.onBack = onBack
        self.onOpenAssetDetails = onOpenAssetDetails

        let categoryViewModels = Dictionary(
            uniqueKeysWithValues: TradingAssetCategory.allCases.map { category in
                (
                    category,
                    TradeAssetsListCategoryViewModel(
                        category: category,
                        assetsListService: assetsListService,
                        amountFormatter: amountFormatter,
                        signedAmountFormatter: signedAmountFormatter,
                        onWillPerformSearch: { [analyticsProvider, analyticsSource] query in
                            analyticsProvider.log(
                                TradeSearch(
                                    from: analyticsSource.tradeSearch,
                                    query: query
                                )
                            )
                        }
                    )
                )
            }
        )
        self.categoryViewModels = categoryViewModels
        self.currentQueryViewModel = categoryViewModels[selectedCategory]?.queryViewModel(for: nil)
            ?? TradeAssetsListCategoryViewModel(
                category: selectedCategory,
                assetsListService: assetsListService,
                amountFormatter: amountFormatter,
                signedAmountFormatter: signedAmountFormatter,
                onWillPerformSearch: { [analyticsProvider, analyticsSource] query in
                    analyticsProvider.log(
                        TradeSearch(
                            from: analyticsSource.tradeSearch,
                            query: query
                        )
                    )
                }
            ).queryViewModel(for: nil)
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        activateCurrentQuery()
    }

    func refresh() async {
        await currentQueryViewModel.refresh()
    }

    func updateSearchText(_ value: String) {
        guard searchText != value else { return }

        searchText = value
        guard hasLoaded else { return }
        scheduleQueryActivation(debounced: true)
    }

    func selectCategory(_ category: TradingAssetCategory) {
        guard selectedCategory != category else { return }

        cancelActivateQueryTask()

        selectedCategory = category

        guard hasLoaded else { return }
        activateCurrentQuery()
    }

    func contentViewModel(for category: TradingAssetCategory) -> TradeAssetsListQueryViewModel {
        if category == selectedCategory {
            return currentQueryViewModel
        }

        return categoryViewModels[category]?.queryViewModel(for: nil)
            ?? currentQueryViewModel
    }

    func loadNextPageIfNeeded(currentAsset: TradingAsset) {
        currentQueryViewModel.loadNextPageIfNeeded(currentAsset: currentAsset)
    }

    func back() {
        disappeared()
        onBack()
    }

    func disappeared() {
        guard !hasDisappeared else { return }

        hasDisappeared = true
        cancelActivateQueryTask()
        categoryViewModels.values.forEach { $0.disappeared() }
    }

    func openAsset(_ asset: TradingAsset) {
        analyticsProvider.log(
            TradeSearchClick(
                from: analyticsSource.tradeSearchClick,
                query: normalizedSearchText,
                asset: asset.id
            )
        )
        onOpenAssetDetails(asset)
    }
}

private extension TradeAssetsListViewModel {
    var normalizedSearchText: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func scheduleQueryActivation(debounced: Bool) {
        cancelActivateQueryTask()

        let delay = debounced ? Constants.searchDebounceNanoseconds : 0
        let query = normalizedSearchText
        let category = selectedCategory

        activateQueryTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            self?.activateQuery(
                query: query,
                category: category
            )
        }
    }

    func activateCurrentQuery() {
        activateQuery(
            query: normalizedSearchText,
            category: selectedCategory
        )
    }

    func activateQuery(
        query: String?,
        category: TradingAssetCategory
    ) {
        guard let categoryViewModel = categoryViewModels[category] else {
            return
        }

        let queryViewModel = categoryViewModel.queryViewModel(for: query)
        if currentQueryViewModel !== queryViewModel {
            currentQueryViewModel = queryViewModel
        }
        queryViewModel.appeared()
    }

    func cancelActivateQueryTask() {
        activateQueryTask?.cancel()
        activateQueryTask = nil
    }
}
