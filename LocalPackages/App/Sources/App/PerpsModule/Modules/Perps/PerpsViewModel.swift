import Foundation
import KeeperCore
import SwiftUI

@MainActor
final class PerpsViewModel: ObservableObject {
    typealias MarketItem = PerpsMarketRowItem

    enum AccountState {
        case resolving
        case inactive
        case active(Portfolio)

        struct Portfolio {
            let accountIndex: Int64
            let balanceText: String
            let positions: [PerpsPositionRowItem]
            let positionsTotal: PerpsPositionsTotal?
        }
    }

    enum MarketsState {
        case loading
        case loaded(items: [MarketItem], isLoadingNextPage: Bool)
        case failed(String)
    }

    @Published private(set) var accountState: AccountState = .resolving
    @Published private(set) var marketsState: MarketsState = .loading
    @Published private(set) var sort: PerpsMarketsSort = .volume

    var onBack: (() -> Void)?
    var onLearnBasics: (() -> Void)?
    var onSearch: (() -> Void)?
    var onHistory: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onWithdraw: (() -> Void)?
    var onSelectMarket: ((Int64) -> Void)?

    private let marketsStore: PerpsMarketsStore
    private let priceInterest: PerpsMarketsPriceInterest
    private let accountStore: PerpsAccountStore

    private var visibleMarketIds: Set<Int64> = []
    private var lastMarketId: Int64?
    private var hasNextPage = false
    private var itemCache: [Int64: (summary: PerpsMarketSummary, item: MarketItem)] = [:]
    private var iconURLsByMarketId: [Int64: URL] = [:]
    private var requestedIconMarketIds: Set<Int64> = []

    init(
        marketsStore: PerpsMarketsStore,
        accountStore: PerpsAccountStore
    ) {
        self.marketsStore = marketsStore
        priceInterest = marketsStore.makePriceInterest()
        self.accountStore = accountStore
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
        requestedIconMarketIds.removeAll()
        accountStore.subscribePositions()
        accountStore.resolveIfNeeded()
        applyMarkets(marketsStore.getState())
        applyAccount(accountStore.currentWalletState())
        pushVisibleInterest()
    }

    func onDisappear() {
        marketsStore.unsubscribe()
        accountStore.unsubscribePositions()
        priceInterest.clear()
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
}

extension PerpsViewModel.AccountState {
    var isActive: Bool {
        if case .active = self { true } else { false }
    }

    var isResolving: Bool {
        if case .resolving = self { true } else { false }
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
            mergeIconURLs(markets.items.lazy.compactMap { market in
                market.iconURL.map { (market.marketId, $0) }
            })
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
        accountState = viewAccountState(state)
        requestMissingIcons(for: state)
    }

    func viewAccountState(_ state: PerpsAccountStore.State) -> AccountState {
        switch state {
        case .unresolved, .resolving:
            return .resolving
        case .unbound, .inactive:
            return .inactive
        case let .active(account):
            return .active(.init(
                accountIndex: account.accountIndex,
                balanceText: PerpsFormatting.usd(account.availableBalance),
                positions: PerpsPositionRowMapping.rows(from: account.positions) { iconURLsByMarketId[$0] },
                positionsTotal: PerpsPositionRowMapping.total(positions: account.positions)
            ))
        }
    }

    func mergeIconURLs(_ icons: some Sequence<(Int64, URL)>) {
        var didChange = false
        for (marketId, iconURL) in icons where iconURLsByMarketId[marketId] != iconURL {
            iconURLsByMarketId[marketId] = iconURL
            didChange = true
        }
        guard didChange else { return }
        let state = accountStore.currentWalletState()
        if case .active = state { applyAccount(state) }
    }

    func requestMissingIcons(for state: PerpsAccountStore.State) {
        guard case let .active(account) = state else { return }
        let missing = account.positions
            .map(\.marketId)
            .filter { iconURLsByMarketId[$0] == nil && !requestedIconMarketIds.contains($0) }
        guard !missing.isEmpty else { return }
        requestedIconMarketIds.formUnion(missing)
        for marketId in missing {
            Task { [weak self] in
                guard let self else { return }
                guard let iconURL = await marketsStore.snapshot(marketId: marketId)?.iconURL else { return }
                mergeIconURLs([(marketId, iconURL)])
            }
        }
    }
}
