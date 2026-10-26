import Foundation
import PerpsModels
import SwiftUI
import TKLocalize
import TKLogging

@MainActor
final class PerpsViewModel: ObservableObject, PerpsRootViewModeling {
    typealias MarketItem = PerpsMarketRowItem
    typealias AccountState = PerpsRootAccountState
    typealias MarketsState = PerpsRootMarketsState

    @Published private(set) var accountState: AccountState = .resolving
    @Published private(set) var marketsState: MarketsState = .loading
    @Published private(set) var sort: PerpsMarketsSort = .volume
    @Published private(set) var fundingToast: PerpsAssetPageTradeToast?

    var zeroBalanceText: String {
        format.usd(0)
    }

    var onBack: (() -> Void)?
    var onLearnBasics: (() -> Void)?
    var onSearch: (() -> Void)?
    var onHistory: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onWithdraw: (() -> Void)?
    var onOpenFunding: ((Set<String>) -> Void)?
    var onSelectMarket: ((Int64) -> Void)?

    private let marketsStore: any PerpsMarketsStoring
    private let priceInterest: any PerpsPriceInteresting
    private let accountStore: any PerpsAccountStoring

    private var visibleMarketIds: Set<Int64> = []
    private var lastMarketId: Int64?
    private var hasNextPage = false
    private var itemCache: [Int64: (summary: PerpsMarketSummary, item: MarketItem)] = [:]
    private var iconURLsByMarketId: [Int64: URL] = [:]
    private var requestedIconMarketIds: Set<Int64> = []
    private var lastLoggedAccountLabel: String?
    private var watchedOperations: Set<String> = []
    private var confirmedToastTask: Task<Void, Never>?
    private var fundingToastTransactions: Set<String> = []

    private let format: PerpsFormatting

    init(
        marketsStore: any PerpsMarketsStoring,
        accountStore: any PerpsAccountStoring,
        format: PerpsFormatting
    ) {
        self.format = format
        self.marketsStore = marketsStore
        priceInterest = marketsStore.makePriceInterest()
        self.accountStore = accountStore
        if case let .loaded(markets) = marketsStore.getState() {
            sort = markets.sort
        }
        observeStores()
        applyAccount(accountStore.currentWalletState())
        applyFunding(accountStore.fundingActivity())
        applyMarkets(marketsStore.getState())
    }

    func onAppear() {
        marketsStore.setSort(sort)
        marketsStore.subscribe()
        requestedIconMarketIds.removeAll()
        accountStore.subscribePositions()
        accountStore.resolveIfNeeded()
        // The balance card only moves on a full portfolio read, and the store stays resolved
        // for as long as any perps screen holds it.
        if case .active = accountStore.currentWalletState() { accountStore.refresh() }
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

private extension PerpsViewModel {
    func observeStores() {
        // Re-read the latest state on each event rather than applying the
        // event's payload: keeps application order-independent (unstructured
        // Tasks aren't FIFO), and routes account state through the
        // wallet-gated accessor so a stale resolve can't surface another
        // wallet's balance.
        marketsStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.applyMarkets(observer.marketsStore.getState()) }
        }
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in
                observer.applyAccount(observer.accountStore.currentWalletState())
                observer.applyFunding(observer.accountStore.fundingActivity())
            }
        }
    }

    func pushVisibleInterest() {
        priceInterest.set(marketIds: visibleMarketIds)
    }

    func applyMarkets(_ state: PerpsMarketsState) {
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
        let item = PerpsMarketRowMapping.item(from: summary, format: format)
        itemCache[summary.marketId] = (summary, item)
        return item
    }

    func applyAccount(_ state: PerpsWalletAccountState) {
        accountState = viewAccountState(state)
        logAccount(accountState)
        requestMissingIcons(for: state)
    }

    func logAccount(_ state: AccountState) {
        let label: String
        switch state {
        case .resolving: label = "resolving"
        case .inactive: label = "inactive"
        case let .active(portfolio):
            label = "active balance=\(portfolio.balanceText) positions=\(portfolio.positions.count) orders=\(portfolio.limitOrders.count)"
        }
        guard label != lastLoggedAccountLabel else { return }
        lastLoggedAccountLabel = label
        Log.perps.i("Home: account → \(label)")
    }

    func viewAccountState(_ state: PerpsWalletAccountState) -> AccountState {
        switch state {
        case .unresolved, .resolving:
            return .resolving
        case .unbound, .inactive:
            return .inactive
        case let .active(account):
            return .active(.init(
                accountIndex: account.accountIndex,
                balanceText: format.usd(account.availableBalance),
                positions: PerpsPositionRowMapping.rows(from: account.positions, format: format) { iconURLsByMarketId[$0] },
                positionsTotal: PerpsPositionRowMapping.total(positions: account.positions, format: format),
                limitOrders: account.openOrders
                    .sorted { ($0.marketId, $0.order.orderIndex) < ($1.marketId, $1.order.orderIndex) }
                    .map(limitOrderRow)
            ))
        }
    }

    func limitOrderRow(_ item: PerpsPortfolioOrder) -> PerpsLimitOrderRowItem {
        let order = item.order
        return PerpsLimitOrderRowItem(
            orderIndex: order.orderIndex,
            marketId: item.marketId,
            symbol: item.symbol,
            iconURL: iconURLsByMarketId[item.marketId],
            sideText: (order.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isLong: order.side == .long,
            valueText: format.usd(order.remainingBaseAmount * order.limitPrice),
            limitText: TKLocales.Perps.limitOrderSubtitle(format.usd(order.limitPrice))
        )
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

    func requestMissingIcons(for state: PerpsWalletAccountState) {
        guard case let .active(account) = state else { return }
        let missing = Set(account.positions.map(\.marketId) + account.openOrders.map(\.marketId))
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

extension PerpsViewModel {
    /// Only an operation seen on its way is announced as arrived: one completed before this
    /// screen watched it has nothing left to say.
    func applyFunding(_ activity: PerpsFundingActivity) {
        let arrived = watchedOperations.intersection(activity.completed)
        watchedOperations = activity.inFlight.union(activity.pending)
        if !activity.inFlight.isEmpty {
            confirmedToastTask?.cancel()
            confirmedToastTask = nil
            fundingToast = .progress(TKLocales.Perps.Toast.depositSending)
            fundingToastTransactions = transactions(of: activity.inFlight, in: activity)
        } else if !arrived.isEmpty {
            fundingToast = .success(TKLocales.Perps.Toast.depositConfirmed)
            fundingToastTransactions = transactions(of: arrived, in: activity)
            confirmedToastTask?.cancel()
            confirmedToastTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                self?.fundingToast = nil
                self?.fundingToastTransactions = []
                self?.confirmedToastTask = nil
            }
        } else if confirmedToastTask == nil {
            fundingToast = nil
            fundingToastTransactions = []
        }
    }

    func openFundingToast() {
        guard fundingToast != nil else { return }
        onOpenFunding?(fundingToastTransactions)
    }

    private func transactions(of operations: Set<String>, in activity: PerpsFundingActivity) -> Set<String> {
        operations.reduce(into: []) { $0.formUnion(activity.transactions[$1] ?? []) }
    }
}
