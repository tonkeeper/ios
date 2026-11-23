import Foundation
import KeeperCore
import Perps
import PerpsModels
import TKCore

@MainActor
final class MultichainWalletPerpsSectionViewModel: ObservableObject {
    enum Content {
        case hidden
        case shelf([PerpsShelfMarketViewData])
        case positions(PerpsPositionsPreview)
    }

    @Published private(set) var content: Content = .hidden
    @Published private(set) var balanceText: String?

    var onOpenPerps: ((PerpsEntryPoint) -> Void)?
    var onOpenMarket: ((Int64, PerpsEntryPoint) -> Void)?

    /// Held, not read: the assembly caches scopes weakly, so this is what keeps the wallet
    /// home and the perps screens on one account store for as long as the section exists.
    private let walletScope: PerpsWalletScope?
    private let wallet: Wallet
    private let portfolioStore: MultichainPortfolioStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let amountFormatter: AmountFormatter
    private let portfolioFormatting = MultichainPortfolioAmountFormatting()
    private let accountStore: any PerpsAccountStoring
    private let marketsStore: any PerpsMarketsStoring
    private let shelfMarketsLoader: () async throws -> [PerpsMarketSummary]
    private let itemsMapper: TradeItemsMapper
    private let format: PerpsFormatting

    private var iconURLsByMarketId: [Int64: URL] = [:]
    private var requestedIconMarketIds: Set<Int64> = []
    private var shelfMarkets: [PerpsShelfMarketViewData] = []
    private var didAttemptShelfLoad = false
    private var shelfLoadTask: Task<Void, Never>?
    private var isOnScreen = false
    private var isSubscribedToPositions = false

    init(
        wallet: Wallet,
        portfolioStore: MultichainPortfolioStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        amountFormatter: AmountFormatter,
        accountStore: any PerpsAccountStoring,
        marketsStore: any PerpsMarketsStoring,
        itemsMapper: TradeItemsMapper,
        shelfMarketsLoader: @escaping () async throws -> [PerpsMarketSummary],
        walletScope: PerpsWalletScope? = nil
    ) {
        self.walletScope = walletScope
        self.wallet = wallet
        self.portfolioStore = portfolioStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        format = .live(appSettingsStore: appSettingsStore)
        self.amountFormatter = amountFormatter
        self.accountStore = accountStore
        self.marketsStore = marketsStore
        self.itemsMapper = itemsMapper
        self.shelfMarketsLoader = shelfMarketsLoader
        observeAccountStore()
        applyAccount(accountStore.currentWalletState())
    }

    func onAppear() {
        guard !isOnScreen else { return }
        isOnScreen = true
        requestedIconMarketIds.removeAll()
        didAttemptShelfLoad = false
        accountStore.resolveIfNeeded()
        // The balance only moves on a full portfolio read, and the store now stays resolved
        // for as long as any perps screen holds it, so entering the screen is what refreshes it.
        if case .active = accountStore.currentWalletState() { accountStore.refreshOnAppear() }
        applyAccount(accountStore.currentWalletState())
    }

    func refresh() {
        guard isOnScreen else { return }
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving:
            return
        case .unbound, .inactive, .active:
            break
        }
        didAttemptShelfLoad = false
        shelfLoadTask?.cancel()
        shelfLoadTask = nil
        loadShelfMarketsIfNeeded()
        accountStore.refresh()
    }

    func onDisappear() {
        guard isOnScreen else { return }
        isOnScreen = false
        unsubscribeFromPositions()
        shelfLoadTask?.cancel()
        shelfLoadTask = nil
    }

    func openPerps() {
        onOpenPerps?(entryPoint)
    }

    func openMarket(_ marketId: Int64) {
        onOpenMarket?(marketId, entryPoint)
    }

    deinit {
        shelfLoadTask?.cancel()
        if isSubscribedToPositions {
            accountStore.unsubscribePositions(cadence: .ambient)
        }
    }
}

private extension MultichainWalletPerpsSectionViewModel {
    var entryPoint: PerpsEntryPoint {
        if case .positions = content { .mainPositions } else { .mainCarousel }
    }

    func observeAccountStore() {
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.applyCurrentAccountOnScreen() }
        }
        portfolioStore.addObserver(self) { observer, event in
            guard case let .didUpdatePortfolio(wallet) = event else { return }
            Task { @MainActor in
                guard wallet == observer.wallet else { return }
                observer.applyCurrentAccountOnScreen()
            }
        }
        appSettingsStore.addObserver(self) { observer, event in
            guard case .didUpdateIsSecureMode = event else { return }
            Task { @MainActor in observer.applyCurrentAccountOnScreen() }
        }
    }

    /// The perps screens pushed over the wallet home keep the account store busy; `onAppear` catches up.
    func applyCurrentAccountOnScreen() {
        guard isOnScreen else { return }
        applyAccount(accountStore.currentWalletState())
    }

    func perpsBalanceText() -> String? {
        guard let fiatPrice = portfolioStore.getState()[wallet]?.perpsFiatPrice,
              let total = portfolioFormatting.portfolioFiatTotalAndCurrency(
                  from: fiatPrice,
                  displayCurrency: currencyStore.getState()
              )
        else { return nil }
        if appSettingsStore.getState().isSecureMode { return .secureModeValueShort }
        return amountFormatter.format(decimal: total.amount, accessory: .fiat(total.currency), style: .fiatBalance)
    }

    func applyAccount(_ state: PerpsWalletAccountState) {
        switch state {
        case .unresolved, .resolving:
            // Nothing is known yet. Falling back to the shelf here would flash it over the
            // positions of a wallet that has them, every time the store is rebuilt.
            return
        case .unbound, .inactive:
            unsubscribeFromPositions()
            balanceText = nil
            showShelf()
            return
        case .active:
            break
        }
        guard case let .active(account) = state else { return }
        subscribeToPositionsIfNeeded()
        balanceText = perpsBalanceText()
        guard account.positionsLoaded || !account.hasReadOnlyToken else { return }
        guard !account.positions.isEmpty else {
            showShelf()
            return
        }
        requestMissingIcons(for: account.positions)
        content = .positions(PerpsPositionRowMapping.preview(
            from: account.positions,
            format: format,
            iconURL: { iconURLsByMarketId[$0] }
        ))
    }

    /// Only an activated account polls positions, so a wallet that never opened perps costs
    /// the wallet home nothing.
    func subscribeToPositionsIfNeeded() {
        guard isOnScreen, !isSubscribedToPositions else { return }
        isSubscribedToPositions = true
        accountStore.subscribePositions(cadence: .ambient)
    }

    func unsubscribeFromPositions() {
        guard isSubscribedToPositions else { return }
        isSubscribedToPositions = false
        accountStore.unsubscribePositions(cadence: .ambient)
    }

    func showShelf() {
        content = shelfMarkets.isEmpty ? .hidden : .shelf(shelfMarkets)
        loadShelfMarketsIfNeeded()
    }

    func loadShelfMarketsIfNeeded() {
        guard isOnScreen, !didAttemptShelfLoad, shelfLoadTask == nil else { return }
        shelfLoadTask = Task { [weak self] in
            let markets = try? await self?.shelfMarketsLoader()
            // Everything here is main-actor isolated, so a cancel from refresh/onDisappear is
            // always visible by the time this resumes — the task handle is the only identity needed.
            guard let self, !Task.isCancelled else { return }
            shelfLoadTask = nil
            didAttemptShelfLoad = true
            guard let markets else { return }
            shelfMarkets = PerpsShelfMarketMapping.items(from: markets, itemsMapper: itemsMapper)
            applyAccount(accountStore.currentWalletState())
        }
    }

    func requestMissingIcons(for positions: [PerpsPositionSummary]) {
        let missing = positions
            .map(\.marketId)
            .filter { iconURLsByMarketId[$0] == nil && !requestedIconMarketIds.contains($0) }
        guard !missing.isEmpty else { return }
        requestedIconMarketIds.formUnion(missing)
        for marketId in missing {
            Task { [weak self] in
                guard let self else { return }
                guard let iconURL = await marketsStore.snapshot(marketId: marketId)?.iconURL else { return }
                guard iconURLsByMarketId[marketId] != iconURL else { return }
                iconURLsByMarketId[marketId] = iconURL
                applyAccount(accountStore.currentWalletState())
            }
        }
    }
}
