import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

@MainActor
protocol TokenManagementModuleOutput: AnyObject {}

@MainActor
protocol TokenManagementModuleInput: AnyObject {}

@MainActor
final class TokenManagementViewModelImplementation:
    ObservableObject,
    TokenManagementModuleOutput,
    TokenManagementModuleInput
{
    private enum Constants {
        static let allCategoryID = "all"
        static let searchDebounceNanoseconds: UInt64 = 300_000_000
    }

    @Published private(set) var searchText = ""
    @Published private(set) var categories = [TokenManagementCategory]()
    @Published private(set) var selectedCategoryID = Constants.allCategoryID
    @Published private(set) var currentQueryViewModel: TokenManagementQueryViewModel?
    @Published private(set) var hiddenItemIDs = Set<String>()
    @Published private(set) var isSaveButtonVisible = false
    @Published private(set) var hidesDustBalances: Bool

    var didRequestClose: (() -> Void)?
    var didSaveChanges: ((TokenManagementVisibilityUpdate) -> Void)?

    private let service: TokenManagementService
    private let appSettingsStore: AppSettingsStore
    private let categoryViewModels: [String: TokenManagementCategoryViewModel]

    private var persistedHiddenIDs = Set<String>()
    private var draftHiddenIDs = Set<String>()
    private var userEditedIDs = Set<String>()
    private var hasLoaded = false
    private var hasDisappeared = false
    private var activateQueryTask: Task<Void, Never>?

    init(
        availableChains: [TokenManagementChain],
        service: TokenManagementService,
        appSettingsStore: AppSettingsStore
    ) {
        self.service = service
        self.appSettingsStore = appSettingsStore
        let appSettings = appSettingsStore.getState()
        self.hidesDustBalances = appSettings.hidesDustBalances

        let allCategories = [
            TokenManagementCategory(
                id: Constants.allCategoryID,
                title: TKLocales.Trade.Assets.Categories.all
            ),
        ] + availableChains.map {
            TokenManagementCategory(
                id: $0.id,
                title: $0.title,
                icon: $0.icon
            )
        }
        categories = allCategories
        categoryViewModels = Dictionary(
            uniqueKeysWithValues: allCategories.map { category in
                (
                    category.id,
                    TokenManagementCategoryViewModel(
                        categoryID: category.id,
                        allCategoryID: Constants.allCategoryID,
                        service: service
                    )
                )
            }
        )
        currentQueryViewModel = categoryViewModels[Constants.allCategoryID]?.queryViewModel(
            for: nil,
            hidesDustBalances: hidesDustBalances
        )

        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateBalanceFilter:
                Task { @MainActor in
                    observer.refreshBalanceFilter()
                }
            case .didUpdateIsSecureMode, .didUpdateSearchEngine, .didUpdateHistoryFilter:
                break
            }
        }
    }

    func setHidesDustBalances(_ hidesDustBalances: Bool) {
        guard self.hidesDustBalances != hidesDustBalances else {
            return
        }

        self.hidesDustBalances = hidesDustBalances
        persistBalanceFilters()
        activateCurrentQuery()
    }

    func viewDidLoad() {
        persistedHiddenIDs = []
        draftHiddenIDs = []
        userEditedIDs = []
        hiddenItemIDs = draftHiddenIDs
        updateSaveButtonVisibility()

        service.didLoadBalances = { [weak self] balances in
            self?.mergeLoadedBalances(balances)
        }

        guard !hasLoaded else {
            return
        }
        hasLoaded = true
        activateCurrentQuery()
    }

    func updateSearchText(_ value: String) {
        guard searchText != value else {
            return
        }

        searchText = value
        guard hasLoaded else {
            return
        }
        scheduleQueryActivation(debounced: true)
    }

    func close() {
        disappeared()
        didRequestClose?()
    }

    func selectCategory(_ categoryID: String) {
        guard selectedCategoryID != categoryID else {
            return
        }

        cancelActivateQueryTask()
        selectedCategoryID = categoryID

        guard hasLoaded else {
            return
        }
        activateCurrentQuery()
    }

    func toggleVisibility(for identifier: String) {
        userEditedIDs.insert(identifier)
        if draftHiddenIDs.contains(identifier) {
            draftHiddenIDs.remove(identifier)
        } else {
            draftHiddenIDs.insert(identifier)
        }
        hiddenItemIDs = draftHiddenIDs
        updateSaveButtonVisibility()
    }

    func saveChanges() {
        let idsToHide = draftHiddenIDs.subtracting(persistedHiddenIDs)
        let idsToShow = persistedHiddenIDs.subtracting(draftHiddenIDs)
        let changes = idsToHide.map {
            MultichainAssetFilterChange(assetId: $0, action: .hide)
        } + idsToShow.map {
            MultichainAssetFilterChange(assetId: $0, action: .show)
        }
        guard !changes.isEmpty else {
            close()
            return
        }

        let update: TokenManagementVisibilityUpdate
        do {
            update = try service.saveVisibilityChanges(changes)
        } catch {
            return
        }
        persistedHiddenIDs = draftHiddenIDs
        userEditedIDs.removeAll()
        hiddenItemIDs = draftHiddenIDs
        updateSaveButtonVisibility()
        disappeared()
        didSaveChanges?(update)
    }

    func retryLoadingAssets() {
        Task {
            await currentQueryViewModel?.refresh()
        }
    }

    func disappeared() {
        guard !hasDisappeared else {
            return
        }

        hasDisappeared = true
        cancelActivateQueryTask()
        service.didLoadBalances = nil
        categoryViewModels.values.forEach { $0.disappeared() }
    }
}

private extension TokenManagementViewModelImplementation {
    func refreshBalanceFilter() {
        let state = appSettingsStore.getState()
        guard hidesDustBalances != state.hidesDustBalances else {
            return
        }
        hidesDustBalances = state.hidesDustBalances
        activateCurrentQuery()
    }

    func persistBalanceFilters() {
        appSettingsStore.setHidesDustBalances(hidesDustBalances)
    }

    var normalizedSearchText: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func mergeLoadedBalances(_ balances: [TokenManagementBalanceItem]) {
        let pageIDs = Set(balances.map(\.id))
        let pageHiddenIDs = Set(balances.filter(\.isHidden).map(\.id))

        persistedHiddenIDs.subtract(pageIDs)
        persistedHiddenIDs.formUnion(pageHiddenIDs)

        for id in pageIDs where !userEditedIDs.contains(id) {
            if pageHiddenIDs.contains(id) {
                draftHiddenIDs.insert(id)
            } else {
                draftHiddenIDs.remove(id)
            }
        }

        hiddenItemIDs = draftHiddenIDs
        updateSaveButtonVisibility()
    }

    func updateSaveButtonVisibility() {
        isSaveButtonVisible = draftHiddenIDs != persistedHiddenIDs
    }

    func scheduleQueryActivation(debounced: Bool) {
        cancelActivateQueryTask()

        let delay = debounced ? Constants.searchDebounceNanoseconds : 0
        let query = normalizedSearchText
        let categoryID = selectedCategoryID

        activateQueryTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else {
                return
            }
            self?.activateQuery(
                query: query,
                categoryID: categoryID
            )
        }
    }

    func activateCurrentQuery() {
        activateQuery(
            query: normalizedSearchText,
            categoryID: selectedCategoryID
        )
    }

    func activateQuery(
        query: String?,
        categoryID: String
    ) {
        guard let queryViewModel = categoryViewModels[categoryID]?.queryViewModel(
            for: query,
            hidesDustBalances: hidesDustBalances
        ) else {
            currentQueryViewModel?.disappeared()
            currentQueryViewModel = nil
            return
        }

        if currentQueryViewModel !== queryViewModel {
            currentQueryViewModel?.disappeared()
            currentQueryViewModel = queryViewModel
        }
        if hasLoaded {
            queryViewModel.appeared()
        }
    }

    func cancelActivateQueryTask() {
        activateQueryTask?.cancel()
        activateQueryTask = nil
    }
}
