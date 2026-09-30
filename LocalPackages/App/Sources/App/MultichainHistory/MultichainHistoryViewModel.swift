import AppUI
import Combine
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

struct MultichainHistoryContentDescriptor: Identifiable {
    let id: MultichainHistoryCategory
    let queryViewModel: MultichainHistoryQueryViewModel
    let isActive: Bool
}

@MainActor
final class MultichainHistoryViewModelImplementation: ObservableObject {
    @Published private(set) var chainTabs = [MultichainHistoryChainTab]()
    @Published private(set) var selectedChainFilter: MultichainHistoryChainFilter = .all
    @Published private(set) var selectedTypeFilter: MultichainHistoryTypeFilter = .all
    @Published private(set) var hidesDustTransactions: Bool
    @Published private(set) var contentDescriptors = [MultichainHistoryContentDescriptor]()

    var currentQueryViewModel: MultichainHistoryQueryViewModel? {
        contentDescriptors.first(where: \.isActive)?.queryViewModel
    }

    var typeFilterItems: [MultichainHistoryTypeFilterItem] {
        availableTypeFilters.map { filter in
            MultichainHistoryTypeFilterItem(
                id: filter,
                title: filter.title,
                isSelected: filter == selectedTypeFilter
            )
        }
    }

    var selectedTypeFilterTitle: String {
        switch selectedTypeFilter {
        case .all:
            return TKLocales.History.Tab.allTypes
        case .send, .receive, .swap, .perps, .spam:
            return selectedTypeFilter.title
        }
    }

    var availableTypeFilters: [MultichainHistoryTypeFilter] {
        MultichainHistoryTypeFilter.allCases.filter { $0 != .perps || showsPerps }
    }

    func isTypeFilterActionBarVisible(for queryViewModel: MultichainHistoryQueryViewModel) -> Bool {
        selectedTypeFilter != .all || queryViewModel.hasActivityItems
    }

    var onHistoryFiltersChange: ((_ hidesDustTransactions: Bool) -> Void)?

    private let multichainState: MultichainWalletState
    private let assetId: String?
    private let showsPerps: Bool
    private let multichainService: MultichainService
    private let realtimeManager: MultichainRealtimeManager?
    private let reachabilityTracker: ReachabilityTracker?
    private let amountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter
    private let nftResolver: MultichainActivityNFTResolver
    private let currentDateProvider: () -> Date
    private let chainImageProvider: (MultichainChain) -> UIImage?
    private let onAddFunds: () -> Void

    private var categoryViewModels = [MultichainHistoryCategory: MultichainHistoryCategoryViewModel]()
    private var nftResolutionObservation: AnyCancellable?
    private var hasLoaded = false

    init(
        multichainState: MultichainWalletState,
        assetId: String? = nil,
        hidesDustTransactions: Bool = false,
        isPerpsEnabled: Bool = false,
        multichainService: MultichainService,
        realtimeManager: MultichainRealtimeManager? = nil,
        reachabilityTracker: ReachabilityTracker? = nil,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        nftResolver: MultichainActivityNFTResolver,
        currentDateProvider: @escaping () -> Date = Date.init,
        chainImageProvider: @escaping (MultichainChain) -> UIImage? = { $0.addressConfiguration.icon },
        onAddFunds: @escaping () -> Void = {}
    ) {
        self.multichainState = multichainState
        self.assetId = assetId
        self.showsPerps = isPerpsEnabled && assetId == nil
        self.hidesDustTransactions = hidesDustTransactions
        self.multichainService = multichainService
        self.realtimeManager = realtimeManager
        self.reachabilityTracker = reachabilityTracker
        self.amountFormatter = amountFormatter
        self.dateFormatter = dateFormatter
        self.nftResolver = nftResolver
        self.currentDateProvider = currentDateProvider
        self.chainImageProvider = chainImageProvider
        self.onAddFunds = onAddFunds
        self.nftResolutionObservation = nftResolver.$revision
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        realtimeManager?.addHistoryInvalidationObserver(self) { observer, walletId in
            Task { @MainActor in
                guard observer.multichainState.walletId == walletId else { return }
                await observer.refresh()
            }
        }
    }

    func viewDidLoad() {
        guard !hasLoaded else {
            return
        }

        if assetId == nil {
            let filters = makeChainFilters(addresses: multichainState.addresses)
            chainTabs = makeChainTabs(filters: filters)
            if !filters.contains(selectedChainFilter) {
                selectedChainFilter = .all
            }
        }

        hasLoaded = true
        reachabilityTracker?.addObserver(self)
        activateCurrentCategory()
    }

    func selectChainFilter(_ filter: MultichainHistoryChainFilter) {
        guard selectedChainFilter != filter else {
            return
        }

        selectedChainFilter = filter
        guard hasLoaded else {
            return
        }
        activateCurrentCategory()
    }

    func selectTypeFilter(_ filter: MultichainHistoryTypeFilter) {
        guard selectedTypeFilter != filter else {
            return
        }

        selectedTypeFilter = filter
        guard hasLoaded else {
            return
        }
        activateCurrentCategory()
    }

    func setHidesDustTransactions(_ hidesDustTransactions: Bool) {
        guard self.hidesDustTransactions != hidesDustTransactions else {
            return
        }

        self.hidesDustTransactions = hidesDustTransactions
        reloadForHistoryFiltersChange()
        onHistoryFiltersChange?(hidesDustTransactions)
    }

    func refresh() async {
        await currentQueryViewModel?.refresh()
    }

    func disappeared() {
        categoryViewModels.values.forEach { $0.disappeared() }
    }

    func contentViewModel(for category: MultichainHistoryCategory) -> MultichainHistoryQueryViewModel {
        categoryViewModel(for: category).queryViewModel()
    }

    func transactionDetailsModel(for activity: MultichainActivity) -> MultichainTransactionDetailsModel {
        MultichainTransactionDetailsModelBuilder(
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            transactionButtonProvider: MultichainTransactionDetailsModelBuilder.transactionButton,
            nftProvider: { [nftResolver] in nftResolver.nft(for: $0) }
        ).build(activity: activity)
    }
}

extension MultichainHistoryViewModelImplementation: ReachabilityTrackerObserver {
    nonisolated func didUpdateState(_ state: ReachabilityTracker.State) {
        guard case .connected = state else {
            return
        }
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }
}

private extension MultichainHistoryViewModelImplementation {
    var currentCategory: MultichainHistoryCategory {
        if let assetId {
            return .asset(assetId: assetId, typeFilter: selectedTypeFilter)
        }
        return .chain(chainFilter: selectedChainFilter, typeFilter: selectedTypeFilter)
    }

    func activateCurrentCategory() {
        let category = currentCategory
        let queryViewModel = contentViewModel(for: category)
        currentQueryViewModel?.disappeared()
        updateContentDescriptors(
            activeCategory: category,
            activeQueryViewModel: queryViewModel
        )
        queryViewModel.appeared()
    }

    func updateContentDescriptors(
        activeCategory: MultichainHistoryCategory,
        activeQueryViewModel: MultichainHistoryQueryViewModel
    ) {
        var descriptors = contentDescriptors
            .filter { $0.id != activeCategory }
            .map {
                MultichainHistoryContentDescriptor(
                    id: $0.id,
                    queryViewModel: $0.queryViewModel,
                    isActive: false
                )
            }
        descriptors.append(
            MultichainHistoryContentDescriptor(
                id: activeCategory,
                queryViewModel: activeQueryViewModel,
                isActive: true
            )
        )
        contentDescriptors = descriptors
    }

    func categoryViewModel(for category: MultichainHistoryCategory) -> MultichainHistoryCategoryViewModel {
        if let categoryViewModel = categoryViewModels[category] {
            return categoryViewModel
        }

        let categoryViewModel = MultichainHistoryCategoryViewModel(
            multichainState: multichainState,
            category: category,
            hidesDustTransactions: hidesDustTransactions,
            showsPerps: showsPerps,
            multichainService: multichainService,
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            nftResolver: nftResolver,
            currentDateProvider: currentDateProvider,
            onAddFunds: onAddFunds
        )
        categoryViewModels[category] = categoryViewModel
        return categoryViewModel
    }

    func reloadForHistoryFiltersChange() {
        guard hasLoaded else { return }
        currentQueryViewModel?.disappeared()
        categoryViewModels = [:]
        contentDescriptors = []
        activateCurrentCategory()
    }

    func makeChainFilters(addresses: [MultichainWalletAddress]) -> [MultichainHistoryChainFilter] {
        var chains = [MultichainChain]()
        var seenChains = Set<MultichainChain>()
        for address in addresses where seenChains.insert(address.chain).inserted {
            chains.append(address.chain)
        }

        let ordered = MultichainChain.orderedByDisplayOrder(chains)

        return [.all] + ordered.map(MultichainHistoryChainFilter.chain)
    }

    func makeChainTabs(filters: [MultichainHistoryChainFilter]) -> [MultichainHistoryChainTab] {
        filters.map { filter in
            switch filter {
            case .all:
                return MultichainHistoryChainTab(
                    id: .all,
                    title: TKLocales.History.Tab.all,
                    image: nil,
                    isSelectable: true
                )
            case let .chain(chain):
                return MultichainHistoryChainTab(
                    id: .chain(chain),
                    title: chain.shortDisplayTitle,
                    image: chainImageProvider(chain),
                    isSelectable: true
                )
            }
        }
    }
}
