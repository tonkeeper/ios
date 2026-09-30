import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
protocol TokenPickerV2ModuleOutput: AnyObject {
    var didFinish: (() -> Void)? { get set }
    var didSelectAsset: ((MultichainAsset) -> Void)? { get set }
    var didSelectPerpMarket: ((Int64) -> Void)? { get set }
    var didDismiss: (() -> Void)? { get set }
    func finishAssetSelection(shouldClose: Bool)
}

@MainActor
final class TokenPickerV2ViewModelImplementation: ObservableObject, TokenPickerV2ModuleOutput {
    private enum Constants {
        static let searchDebounceNanoseconds: UInt64 = 300_000_000
    }

    var didFinish: (() -> Void)?
    var didSelectAsset: ((MultichainAsset) -> Void)?
    var didSelectPerpMarket: ((Int64) -> Void)?
    var didDismiss: (() -> Void)?
    var onCatalogSortOverlayStateChanged: (() -> Void)?

    @Published var searchText = ""
    @Published private(set) var tabs = [TokenPickerV2TabModel]()
    @Published private(set) var selectedChainFilter: TokenPickerV2ChainFilter = .all
    @Published private(set) var currentQueryViewModel: TokenPickerV2QueryViewModel?
    @Published private(set) var showsCatalogSortControl = false
    @Published private(set) var showsPerpsSortControl = false
    @Published private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap
    @Published private(set) var perpsSearchSort: PerpsMarketsSort = .volume
    @Published private(set) var isAwaitingAssetSelection = false

    let headerTitle: String
    let headerStyle: TokenPickerV2HeaderStyle
    let onBack: (() -> Void)?

    var catalogSortButtonTitle: String {
        Self.catalogSortTitle(for: catalogSearchSort)
    }

    private let tokenPickerModel: any TokenPickerV2Model
    private let amountFormatter: AmountFormatter
    private let currencyStore: CurrencyStore
    private let presentation: TokenPickerV2Presentation
    private let waitsForSelectionCompletion: Bool

    private var categoryViewModels = [TokenPickerV2ChainFilter: TokenPickerV2CategoryViewModel]()
    private var activateQueryTask: Task<Void, Never>?
    private(set) var loadFiltersTask: Task<Void, Never>?
    private var hasLoaded = false
    private var hasDisappeared = false

    init(
        headerTitle: String,
        tokenPickerModel: any TokenPickerV2Model,
        amountFormatter: AmountFormatter,
        currencyStore: CurrencyStore,
        presentation: TokenPickerV2Presentation = .modal,
        headerStyle: TokenPickerV2HeaderStyle = .modal,
        waitsForSelectionCompletion: Bool = false,
        onBack: (() -> Void)? = nil
    ) {
        self.headerTitle = headerTitle
        self.headerStyle = headerStyle
        self.tokenPickerModel = tokenPickerModel
        self.amountFormatter = amountFormatter
        self.currencyStore = currencyStore
        self.presentation = presentation
        self.waitsForSelectionCompletion = waitsForSelectionCompletion
        self.onBack = onBack
    }

    func viewDidLoad() {
        apply(state: tokenPickerModel.initialState)
        syncCatalogSortState()
        loadFiltersTask = Task { [weak self] in
            await self?.refreshFiltersIfNeeded()
            guard let self, !Task.isCancelled, !self.hasDisappeared else {
                return
            }
            self.hasLoaded = true
            self.activateCurrentQuery()
        }
    }

    func selectCatalogSort(_ sort: MultichainAssetSearchSort) {
        guard tokenPickerModel.showsCatalogSortControl else {
            return
        }
        guard tokenPickerModel.catalogSearchSort != sort else {
            return
        }

        tokenPickerModel.setCatalogSearchSort(sort)
        syncCatalogSortState()

        categoryViewModels.values.forEach { $0.invalidateCachedQueries() }
        activateCurrentQuery()
    }

    func selectPerpsSort(_ sort: PerpsMarketsSort) {
        guard selectedChainFilter == .perpetuals else {
            return
        }
        guard tokenPickerModel.perpsSearchSort != sort else {
            return
        }

        tokenPickerModel.setPerpsSearchSort(sort)
        syncCatalogSortState()

        categoryViewModels[.perpetuals]?.invalidateCachedQueries()
        activateCurrentQuery()
    }

    func search(text: String) {
        guard searchText != text else {
            return
        }

        searchText = text
        guard hasLoaded else {
            return
        }
        scheduleQueryActivation(debounced: true)
    }

    func selectChainFilter(_ filter: TokenPickerV2ChainFilter) {
        guard selectedChainFilter != filter else {
            return
        }

        cancelActivateQueryTask()
        selectedChainFilter = filter
        syncCatalogSortState()

        guard hasLoaded else {
            return
        }
        activateCurrentQuery()
    }

    func selectRow(_ id: String) {
        guard !isAwaitingAssetSelection,
              let item = currentQueryViewModel?.item(withID: id)
        else {
            return
        }

        switch item.payload {
        case let .asset(asset, _):
            guard let didSelectAsset else {
                return
            }
            if waitsForSelectionCompletion {
                isAwaitingAssetSelection = true
            }
            didSelectAsset(asset)
            guard !waitsForSelectionCompletion else {
                return
            }
            if presentation.closesOnSelection {
                close()
            }
        case let .perp(market):
            didSelectPerpMarket?(market.id)
        }
    }

    func finishAssetSelection(shouldClose: Bool) {
        guard waitsForSelectionCompletion, !hasDisappeared else {
            return
        }

        isAwaitingAssetSelection = false
        if shouldClose {
            close()
        }
    }

    func close() {
        disappeared()
        didFinish?()
    }

    func back() {
        disappeared()
        onBack?()
    }

    func disappeared() {
        guard !hasDisappeared else {
            return
        }

        hasDisappeared = true
        cancelLoadFiltersTask()
        cancelActivateQueryTask()
        categoryViewModels.values.forEach { $0.disappeared() }
        didDismiss?()
    }
}

private extension TokenPickerV2ViewModelImplementation {
    func refreshFiltersIfNeeded() async {
        do {
            guard let filters = try await tokenPickerModel.loadFilters() else {
                return
            }
            guard !Task.isCancelled, !hasDisappeared else {
                return
            }
            let initialFilter = filters.contains(selectedChainFilter)
                ? selectedChainFilter
                : (filters.first ?? .all)
            apply(
                state: TokenPickerV2ModelState(
                    filters: filters,
                    displayMode: tokenPickerModel.initialState.displayMode,
                    initialFilter: initialFilter
                )
            )
        } catch {
            // Keep initial tabs; asset loading still proceeds.
        }
    }

    func syncCatalogSortState() {
        showsPerpsSortControl = selectedChainFilter == .perpetuals
        showsCatalogSortControl = tokenPickerModel.showsCatalogSortControl && !showsPerpsSortControl
        catalogSearchSort = tokenPickerModel.catalogSearchSort
        perpsSearchSort = tokenPickerModel.perpsSearchSort
        onCatalogSortOverlayStateChanged?()
    }

    static func catalogSortTitle(for sort: MultichainAssetSearchSort) -> String {
        switch sort {
        case .marketCap:
            return TKLocales.TokensPicker.Sort.marketCap
        case .volume:
            return TKLocales.TokensPicker.Sort.volume
        case .priceDiffAsc:
            return TKLocales.TokensPicker.Sort.topLosers
        case .priceDiffDesc:
            return TKLocales.TokensPicker.Sort.topGainers
        }
    }

    var normalizedSearchText: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func apply(state: TokenPickerV2ModelState) {
        cancelActivateQueryTask()
        categoryViewModels.values.forEach { $0.disappeared() }
        categoryViewModels.removeAll()

        tabs = makeTabs(filters: state.filters)
        categoryViewModels = Dictionary(
            uniqueKeysWithValues: state.filters.map { filter in
                (
                    filter,
                    TokenPickerV2CategoryViewModel(
                        category: filter,
                        displayMode: state.displayMode,
                        tokenPickerModel: tokenPickerModel,
                        amountFormatter: amountFormatter,
                        currencyStore: currencyStore
                    )
                )
            }
        )
        if !state.filters.contains(selectedChainFilter) {
            selectedChainFilter = state.initialFilter
        }
        currentQueryViewModel = categoryViewModels[selectedChainFilter]?.queryViewModel(for: normalizedSearchText)
    }

    func makeTabs(filters: [TokenPickerV2ChainFilter]) -> [TokenPickerV2TabModel] {
        filters.map { filter in
            switch filter {
            case .all:
                return TokenPickerV2TabModel(
                    id: .all,
                    title: TKLocales.History.Tab.all,
                    image: nil,
                    isSelectable: true
                )
            case let .chain(chain):
                return TokenPickerV2TabModel(
                    id: .chain(chain),
                    title: chain.addressConfiguration.title,
                    image: chain.addressConfiguration.icon,
                    isSelectable: true
                )
            case .perpetuals:
                return TokenPickerV2TabModel(
                    id: .perpetuals,
                    title: TKLocales.Perps.title,
                    image: nil,
                    isSelectable: true
                )
            }
        }
    }

    func scheduleQueryActivation(debounced: Bool) {
        cancelActivateQueryTask()

        let delay = debounced ? Constants.searchDebounceNanoseconds : 0
        let query = normalizedSearchText
        let filter = selectedChainFilter

        activateQueryTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else {
                return
            }

            self?.activateQuery(
                query: query,
                filter: filter
            )
        }
    }

    func activateCurrentQuery() {
        activateQuery(
            query: normalizedSearchText,
            filter: selectedChainFilter
        )
    }

    func activateQuery(
        query: String?,
        filter: TokenPickerV2ChainFilter
    ) {
        guard let categoryViewModel = categoryViewModels[filter] else {
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

    func cancelLoadFiltersTask() {
        loadFiltersTask?.cancel()
        loadFiltersTask = nil
    }
}

struct TokenPickerV2TabModel: Identifiable, Hashable {
    let id: TokenPickerV2ChainFilter
    let title: String
    let image: UIImage?
    let isSelectable: Bool
}

enum TokenPickerV2ChainFilter: Hashable {
    case all
    case chain(MultichainChain)
    case perpetuals
}

extension TokenPickerV2ChainFilter {
    var chain: MultichainChain? {
        switch self {
        case .all, .perpetuals:
            return nil
        case let .chain(chain):
            return chain
        }
    }

    func includes(chain: MultichainChain) -> Bool {
        switch self {
        case .all:
            return true
        case let .chain(expectedChain):
            return expectedChain == chain
        case .perpetuals:
            return false
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .all:
            return "token_picker_chain_all"
        case let .chain(chain):
            return "token_picker_chain_\(chain.rawValue)"
        case .perpetuals:
            return "token_picker_chain_perps"
        }
    }
}
