import Foundation
import KeeperCore
import SwiftUI

@MainActor
final class PerpsViewModel: ObservableObject {
    typealias MarketItem = PerpsMarketRowItem

    enum AccountState {
        case resolving
        case inactive(accountIndex: Int64?)
        case activating
        case active(Portfolio)

        struct Portfolio {
            let accountIndex: Int64
            let balanceText: String
        }
    }

    enum MarketsState {
        case loading
        case loaded(items: [MarketItem], isLoadingNextPage: Bool)
        case failed(String)
    }

    enum ActivationToast: Equatable {
        case activating
        case success
    }

    @Published private(set) var accountState: AccountState = .resolving
    @Published private(set) var marketsState: MarketsState = .loading
    @Published private(set) var sort: PerpsMarketsSort = .volume
    @Published private(set) var activationToast: ActivationToast?
    @Published private(set) var isTestnet = false

    var activationBanner: ActivationToast? {
        accountState.isActivating ? .activating : activationToast
    }

    var onBack: (() -> Void)?
    var onLearnBasics: (() -> Void)?
    var onSearch: (() -> Void)?
    var onHistory: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onActivate: (() -> Void)?
    var onSelectMarket: ((Int64) -> Void)?

    private let marketsStore: PerpsMarketsStore
    private let priceInterest: PerpsMarketsPriceInterest
    private let accountStore: PerpsAccountStore

    private var successToastTask: Task<Void, Never>?
    private var visibleMarketIds: Set<Int64> = []
    private var lastMarketId: Int64?
    private var hasNextPage = false
    private var itemCache: [Int64: (summary: PerpsMarketSummary, item: MarketItem)] = [:]

    init(
        marketsStore: PerpsMarketsStore,
        accountStore: PerpsAccountStore,
        isTestnet: Bool
    ) {
        self.marketsStore = marketsStore
        priceInterest = marketsStore.makePriceInterest()
        self.accountStore = accountStore
        self.isTestnet = isTestnet
        if case let .loaded(markets) = marketsStore.getState() {
            sort = markets.sort
        }
        observeStores()
        applyAccount(accountStore.currentWalletState())
        applyMarkets(marketsStore.getState())
    }

    func onAppear() {
        marketsStore.setSort(sort)
        marketsStore.subscribe()
        accountStore.resolveIfNeeded()
        applyMarkets(marketsStore.getState())
        applyAccount(accountStore.currentWalletState())
        pushVisibleInterest()
    }

    func onDisappear() {
        marketsStore.unsubscribe()
        priceInterest.clear()
        successToastTask?.cancel()
        successToastTask = nil
        activationToast = nil
    }

    func setSort(_ sort: PerpsMarketsSort) {
        guard sort != self.sort else { return }
        self.sort = sort
        marketsStore.setSort(sort)
    }

    func selectMarket(_ id: Int64) {
        onSelectMarket?(id)
    }

    func rowAppeared(_ id: Int64) {
        if id == lastMarketId, hasNextPage {
            marketsStore.loadNextPage()
        }
        guard visibleMarketIds.insert(id).inserted else { return }
        pushVisibleInterest()
    }

    func rowDisappeared(_ id: Int64) {
        guard visibleMarketIds.remove(id) != nil else { return }
        pushVisibleInterest()
    }

    func activate() {
        guard accountState.showsActivationControls else { return }
        onActivate?()
    }
}

extension PerpsViewModel.AccountState {
    var isActive: Bool {
        if case .active = self { true } else { false }
    }

    var isActivating: Bool {
        if case .activating = self { true } else { false }
    }

    var showsActivationControls: Bool {
        if case .inactive = self { true } else { false }
    }

    var showsActivationButton: Bool {
        showsActivationControls || isActivating
    }

    var isActivationButtonEnabled: Bool {
        showsActivationControls
    }

    var portfolio: Portfolio? {
        if case let .active(portfolio) = self { portfolio } else { nil }
    }
}

private extension PerpsViewModel {
    func observeStores() {
        // Re-read the latest state on each event rather than applying the
        // event's payload: keeps application order-independent (unstructured
        // Tasks aren't FIFO), and routes account state through the
        // wallet-gated accessor so a stale resolve can't surface another
        // wallet's balance.
        marketsStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyMarkets(observer.marketsStore.getState()) }
        }
        accountStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyAccount(observer.accountStore.currentWalletState()) }
        }
    }

    func pushVisibleInterest() {
        priceInterest.set(marketIds: visibleMarketIds)
    }

    func applyMarkets(_ state: PerpsMarketsStore.State) {
        switch state {
        case .idle, .loading:
            hasNextPage = false
            lastMarketId = nil
            marketsState = .loading
        case let .loaded(markets):
            let items = markets.items.map(marketItem(for:))
            let marketIds = Set(items.map(\.id))
            itemCache = itemCache.filter { marketIds.contains($0.key) }
            let previousVisibleMarketIds = visibleMarketIds
            visibleMarketIds.formIntersection(marketIds)
            if visibleMarketIds != previousVisibleMarketIds {
                pushVisibleInterest()
            }
            lastMarketId = items.last?.id
            hasNextPage = markets.hasNextPage
            marketsState = .loaded(items: items, isLoadingNextPage: markets.isLoadingNextPage)
        case .failed:
            hasNextPage = false
            lastMarketId = nil
            marketsState = .failed("Failed to load markets")
        }
    }

    func marketItem(for summary: PerpsMarketSummary) -> MarketItem {
        if let cached = itemCache[summary.marketId], cached.summary == summary {
            return cached.item
        }
        let item = PerpsMarketRowMapping.item(from: summary)
        itemCache[summary.marketId] = (summary, item)
        return item
    }

    func applyAccount(_ state: PerpsAccountStore.State) {
        let wasActivating = accountState.isActivating
        accountState = Self.viewAccountState(state)
        // Activation just finished: success → toast, otherwise clear.
        if wasActivating {
            if accountState.isActive { showSuccessToast() } else { hideActivationToast() }
        }
    }

    static func viewAccountState(_ state: PerpsAccountStore.State) -> AccountState {
        switch state {
        case .unresolved, .resolving:
            return .resolving
        case let .inactive(accountIndex):
            return .inactive(accountIndex: accountIndex)
        case .activating:
            return .activating
        case let .active(account):
            return .active(.init(
                accountIndex: account.accountIndex,
                balanceText: PerpsFormatting.usd(account.availableBalance)
            ))
        }
    }

    func showSuccessToast() {
        successToastTask?.cancel()
        activationToast = .success
        successToastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.activationToast = nil
            self?.successToastTask = nil
        }
    }

    func hideActivationToast() {
        successToastTask?.cancel()
        successToastTask = nil
        activationToast = nil
    }
}
