import Foundation
import PerpsModels
import SwiftUI
import TKLocalize
import TKLogging
import UIKit

@MainActor
final class PerpsViewModel: ObservableObject, PerpsRootViewModeling {
    typealias MarketItem = PerpsMarketRowItem
    typealias AccountState = PerpsRootAccountState
    typealias MarketsState = PerpsRootMarketsState

    @Published private(set) var accountState: AccountState = .resolving
    @Published private(set) var loadingPositionsCount = 0
    @Published private(set) var marketsState: MarketsState = .loading
    @Published private(set) var sort: PerpsMarketsSort = .volume
    @Published private(set) var isRegionRestricted: Bool
    let depositStatus: PerpsDepositStatusViewModel?
    let withdrawStatus: PerpsWithdrawStatusViewModel?

    var zeroBalanceText: String {
        format.balance(0)
    }

    var onBack: (() -> Void)?
    var onLearnBasics: (() -> Void)?
    var onSearch: (() -> Void)?
    var onHistory: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onWithdraw: (() -> Void)?
    var onRegionRestrictionInfo: (() -> Void)?
    var onSelectMarket: ((Int64) -> Void)?

    private let marketsStore: any PerpsMarketsStoring
    private let priceInterest: any PerpsPriceInteresting
    private let accountStore: any PerpsAccountStoring
    private let access: () -> PerpsAccess
    private let reloadAccess: () async -> PerpsAccess
    private var accessReload: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?

    private var visibleMarketIds: Set<Int64> = []
    private var lastMarketId: Int64?
    private var hasNextPage = false
    private var itemCache: [Int64: (summary: PerpsMarketSummary, item: MarketItem)] = [:]
    private var isVisible = true
    private var isSubscribed = false
    private var iconURLsByMarketId: [Int64: URL] = [:]
    private var requestedIconMarketIds: Set<Int64> = []
    private var lastLoggedAccountLabel: String?

    private let format: PerpsFormatting

    init(
        marketsStore: any PerpsMarketsStoring,
        accountStore: any PerpsAccountStoring,
        access: @escaping () -> PerpsAccess,
        reloadAccess: @escaping () async -> PerpsAccess,
        format: PerpsFormatting
    ) {
        self.format = format
        self.marketsStore = marketsStore
        priceInterest = marketsStore.makePriceInterest()
        self.accountStore = accountStore
        self.access = access
        self.reloadAccess = reloadAccess
        isRegionRestricted = access() == .restricted
        depositStatus = PerpsDepositStatusViewModel(accountStore: accountStore, format: format)
        withdrawStatus = PerpsWithdrawStatusViewModel(accountStore: accountStore)
        if case let .loaded(markets) = marketsStore.getState() {
            sort = markets.sort
        }
        observeStores()
        applyAccount(accountStore.currentWalletState())
        applyMarkets(marketsStore.getState())
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                self.refreshAccess()
            }
        }
    }

    deinit {
        accessReload?.cancel()
        foregroundObserver.map(NotificationCenter.default.removeObserver)
    }

    func onWillAppear() {
        isVisible = true
        isRegionRestricted = access() == .restricted
        refreshAccess()
        depositStatus?.isVisible = true
        applyMarkets(marketsStore.getState())
        applyAccount(accountStore.currentWalletState())
    }

    func onAppear() {
        isVisible = true
        guard !isSubscribed else { return }
        isSubscribed = true
        marketsStore.setSort(sort)
        marketsStore.subscribe()
        requestedIconMarketIds.removeAll()
        accountStore.subscribePositions()
        accountStore.resolveIfNeeded()
        // The balance card only moves on a full portfolio read, and the store stays resolved
        // for as long as any perps screen holds it.
        if case .active = accountStore.currentWalletState() { accountStore.refreshOnAppear() }
        applyMarkets(marketsStore.getState())
        applyAccount(accountStore.currentWalletState())
        pushVisibleInterest()
    }

    func onDisappear() {
        isVisible = false
        depositStatus?.isVisible = false
        depositStatus?.didInteract()
        guard isSubscribed else { return }
        isSubscribed = false
        marketsStore.unsubscribe()
        accountStore.unsubscribePositions()
        priceInterest.clear()
    }

    func accessDidChange() {
        isRegionRestricted = access() == .restricted
    }

    private func refreshAccess() {
        accessReload?.cancel()
        accessReload = Task { [weak self, reloadAccess] in
            _ = await reloadAccess()
            guard !Task.isCancelled else { return }
            self?.accessDidChange()
        }
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

    /// Until the positions load, the screen holds the room of as many as the wallet had last time.
    static func positionsPlaceholderCount(for state: PerpsWalletAccountState, remembered: Int?) -> Int {
        switch state {
        case .unresolved, .resolving:
            break
        case let .active(account) where !account.positionsLoaded && account.hasReadOnlyToken:
            break
        default:
            return 0
        }
        return min(remembered ?? 0, maxPositionsPlaceholderCount)
    }

    private static let maxPositionsPlaceholderCount = 3
}

private extension PerpsViewModel {
    func observeStores() {
        // Re-read the latest state on each event rather than applying the
        // event's payload: keeps application order-independent (unstructured
        // Tasks aren't FIFO), and routes account state through the
        // wallet-gated accessor so a stale resolve can't surface another
        // wallet's balance.
        marketsStore.addChangeObserver(self) { observer in
            Task { @MainActor in
                guard observer.isVisible else { return }
                observer.applyMarkets(observer.marketsStore.getState())
            }
        }
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in
                if observer.isVisible {
                    observer.applyAccount(observer.accountStore.currentWalletState())
                }
            }
        }
    }

    func pushVisibleInterest() {
        guard isSubscribed else { return }
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
            mergeIcons(markets.items.lazy.map { ($0.marketId, $0.iconURL) })
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
            marketsState = .failed(TKLocales.Perps.Error.marketsLoadFailed)
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
        let newState = viewAccountState(state)
        if accountState != newState {
            accountState = newState
        }
        rememberPositions(of: newState, from: state)
        let placeholderCount = Self.positionsPlaceholderCount(for: state, remembered: accountStore.rememberedPositionsCount)
        if loadingPositionsCount != placeholderCount {
            loadingPositionsCount = placeholderCount
        }
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

    private func rememberPositions(of viewState: AccountState, from state: PerpsWalletAccountState) {
        switch state {
        case let .active(account) where account.positionsLoaded:
            accountStore.rememberPositionsCount(viewState.portfolio?.positions.count ?? 0)
        default:
            break
        }
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
                balanceText: format.balance(account.availableBalance),
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
            leverageText: item.leverage.map { format.leverage($0).uppercased() },
            sideText: (order.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isLong: order.side == .long,
            valueText: item.marginUsd.map { format.balance($0) } ?? "—",
            limitText: TKLocales.Perps.limitOrderSubtitle(format.price(order.limitPrice)),
            autoCloseText: autoCloseText(order.autoCloseLegs)
        )
    }

    func autoCloseText(_ legs: [PerpsTriggerOrderSummary]) -> String? {
        guard let autoClose = PerpsAutoClose(triggerOrders: legs) else { return nil }
        let parts = [
            autoClose.takeProfit.map { "\(TKLocales.Perps.OpenPosition.tp) \(format.price($0.triggerPrice))" },
            autoClose.stopLoss.map { "\(TKLocales.Perps.OpenPosition.sl) \(format.price($0.triggerPrice))" },
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    func mergeIcons(_ entries: some Sequence<(Int64, URL?)>) {
        var didChange = false
        for case let (marketId, iconURL?) in entries where iconURLsByMarketId[marketId] != iconURL {
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
                guard let snapshot = await marketsStore.snapshot(marketId: marketId) else { return }
                mergeIcons([(marketId, snapshot.iconURL)])
            }
        }
    }
}
