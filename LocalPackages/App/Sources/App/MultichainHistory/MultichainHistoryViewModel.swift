import AppUI
import Combine
import Foundation
import KeeperCore
import Perps
import PerpsModels
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
    @Published private(set) var activityToOpen: MultichainActivity?

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
    /// Set as details open: an operation opened in progress keeps a Status row until its outcome.
    var showsFundingStatus = false
    let depositStatus: PerpsDepositStatusViewModel?

    private let multichainState: MultichainWalletState
    private let walletName: String?
    private let assetId: String?
    private let showsPerps: Bool
    private let multichainService: MultichainService
    private let realtimeManager: MultichainRealtimeManager?
    private let reachabilityTracker: ReachabilityTracker?
    private let amountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter
    private let nftResolver: MultichainActivityNFTResolver
    private let encryptedComments: MultichainEncryptedComments?
    private let appSettingsStore: AppSettingsStore
    private let currentDateProvider: () -> Date
    private let chainImageProvider: (MultichainChain) -> UIImage?
    private let onAddFunds: (() -> Void)?
    private let accountStore: (any PerpsAccountStoring)?
    let perpsHistoryEvents: PerpsHistoryEvents?
    /// The assembly caches wallet scopes weakly: holding the scope keeps its funding recovery running.
    private let walletScope: PerpsWalletScope?
    private var unfinishedFunding: Set<String> = []

    private var categoryViewModels = [MultichainHistoryCategory: MultichainHistoryCategoryViewModel]()
    private var nftResolutionObservation: AnyCancellable?
    private var decryptionObservation: AnyCancellable?
    private var pendingEventId: String?
    private var pendingEventObservation: AnyCancellable?
    private var resolvedPendingActivity: MultichainActivity?
    private var hasAppeared = false
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
        encryptedComments: MultichainEncryptedComments? = nil,
        appSettingsStore: AppSettingsStore,
        walletName: String? = nil,
        currentDateProvider: @escaping () -> Date = Date.init,
        chainImageProvider: @escaping (MultichainChain) -> UIImage? = { $0.addressConfiguration.icon },
        onAddFunds: (() -> Void)? = nil,
        pendingEventId: String? = nil,
        walletScope: PerpsWalletScope? = nil,
        accountStore: (any PerpsAccountStoring)? = nil,
        format: PerpsFormatting? = nil,
        perpsHistoryEvents: PerpsHistoryEvents? = nil
    ) {
        self.multichainState = multichainState
        self.walletName = walletName
        self.assetId = assetId
        self.showsPerps = isPerpsEnabled && assetId == nil
        self.hidesDustTransactions = hidesDustTransactions
        self.multichainService = multichainService
        self.realtimeManager = realtimeManager
        self.reachabilityTracker = reachabilityTracker
        self.amountFormatter = amountFormatter
        self.dateFormatter = dateFormatter
        self.nftResolver = nftResolver
        self.encryptedComments = encryptedComments
        self.appSettingsStore = appSettingsStore
        self.currentDateProvider = currentDateProvider
        self.chainImageProvider = chainImageProvider
        self.onAddFunds = onAddFunds
        self.accountStore = accountStore
        self.perpsHistoryEvents = perpsHistoryEvents
        self.walletScope = walletScope
        if let accountStore, let format {
            depositStatus = PerpsDepositStatusViewModel(accountStore: accountStore, format: format)
        } else {
            depositStatus = nil
        }
        let pendingEventId = pendingEventId?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pendingEventId = pendingEventId?.isEmpty == false ? pendingEventId : nil
        self.nftResolutionObservation = nftResolver.$revision
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        self.decryptionObservation = encryptedComments?.$revision
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
        observePendingEvent()
        observeFunding()
    }

    func screenDidAppear() {
        hasAppeared = true
        publishResolvedPendingActivity()
    }

    func didOpenPendingActivity() {
        activityToOpen = nil
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

    func trackedDeposit(matching activity: MultichainActivity) -> PerpsDepositStatus? {
        accountStore?.fundingActivity().unfinishedDeposit(listedAs: activity)
    }

    /// A deposit or withdrawal row turns final only in a fresh page, and the store sees the operation end
    /// first. The steps sheet opens without a selected row, so no other refresh follows it.
    private func observeFunding() {
        guard let accountStore else { return }
        unfinishedFunding = Self.unfinishedFunding(in: accountStore.fundingActivity())
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.fundingDidChange() }
        }
    }

    private func fundingDidChange() {
        guard let activity = accountStore?.fundingActivity() else { return }
        let ended = Self.fundingEnded(from: unfinishedFunding, in: activity)
        unfinishedFunding = Self.unfinishedFunding(in: activity)
        guard ended else { return }
        Task { [weak self] in await self?.refresh() }
    }

    /// Only an operation seen unfinished counts: one the journal loads as already ended changes no row.
    nonisolated static func fundingEnded(from unfinished: Set<String>, in activity: PerpsFundingActivity) -> Bool {
        !unfinished.isDisjoint(with: activity.ended)
    }

    /// Every operation the journal holds that has not ended, an unconfirmed deposit included: it can still be credited.
    nonisolated static func unfinishedFunding(in activity: PerpsFundingActivity) -> Set<String> {
        Set(activity.deposits.map(\.id))
            .union(activity.withdrawals)
            .union(activity.inFlight)
            .union(activity.pending)
            .union(activity.transactions.keys)
            .subtracting(activity.ended)
    }

    func transactionDetailsModel(for activity: MultichainActivity) -> MultichainTransactionDetailsModel {
        MultichainTransactionDetailsModelBuilder(
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            transactionButtonProvider: MultichainTransactionDetailsModelBuilder.transactionButton,
            hidesAmounts: { [weak appSettingsStore] in appSettingsStore?.getState().isSecureMode == true },
            nftProvider: { [nftResolver] in nftResolver.nft(for: $0) },
            walletName: walletName,
            decryptedComment: { [encryptedComments] in encryptedComments?.decryptedComment(of: $0) },
            decryptComment: encryptedComments.map { encryptedComments in { encryptedComments.decrypt($0) } }
        ).build(activity: activity, showsFundingStatus: showsFundingStatus)
    }

    /// The details on screen show an activity with its comment as decrypted so far, so a decryption rebuilds them.
    func detailsItem(for activity: MultichainActivity) -> MultichainActivityDetailsItem {
        MultichainActivityDetailsItem(activity: activity, decryptedComment: encryptedComments?.decryptedComment(of: activity))
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

    func observePendingEvent() {
        guard pendingEventId != nil else {
            return
        }
        let queryViewModel = contentViewModel(for: .chain(chainFilter: .all, typeFilter: .all))
        pendingEventObservation = queryViewModel.$state.sink { [weak self] state in
            Task { @MainActor in
                self?.resolvePendingEvent(in: state)
            }
        }
    }

    func resolvePendingEvent(in state: MultichainHistoryQueryViewModel.State) {
        guard let eventId = pendingEventId else {
            return
        }
        guard let activity = MultichainHistoryEventTarget.activity(
            eventId: eventId,
            in: state.activities
        ) else {
            return
        }
        pendingEventId = nil
        pendingEventObservation = nil
        resolvedPendingActivity = activity
        publishResolvedPendingActivity()
    }

    func publishResolvedPendingActivity() {
        guard hasAppeared, let activity = resolvedPendingActivity else {
            return
        }
        resolvedPendingActivity = nil
        activityToOpen = activity
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
            encryptedComments: encryptedComments,
            appSettingsStore: appSettingsStore,
            currentDateProvider: currentDateProvider,
            onAddFunds: onAddFunds,
            screenRenderOwner: self
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
