import AppUI
import Combine
import Foundation
import KeeperCore
import TKCore

/// Renders the wallet's Earn portfolio from the store the balance loads fill, so the section
/// refreshes whenever the wallet balance does and never loads on its own.
@MainActor
final class WalletBalanceEarnPortfolioViewModel: ObservableObject {
    enum State: Equatable {
        /// Earn is off, or the wallet has no synced multichain wallet to ask about.
        case disabled
        case loading
        case empty
        case positions(EarnPortfolioSectionState)
        case unavailable
    }

    @Published private(set) var state: State = .disabled

    var onSelectPosition: ((EarnPosition) -> Void)?
    var onOpenCatalog: (() -> Void)?

    private var wallet: Wallet
    private let isEnabled: Bool
    private let store: EarnPortfolioStore
    private let balanceLoader: BalanceLoader
    /// Renders amounts as the display settings stand when it is called, secure mode included.
    private let mapper: (EarnPortfolio, Bool) -> EarnPortfolioSectionState
    private let analyticsProvider: AnalyticsProvider
    private let limitModel: WalletSectionLimitModel
    private var limitSubscription: AnyCancellable?
    private var portfolio: EarnPortfolio?
    private var isPositionsViewReported = false

    init(
        wallet: Wallet,
        isEnabled: Bool,
        store: EarnPortfolioStore,
        balanceLoader: BalanceLoader,
        appSettingsStore: AppSettingsStore,
        mapper: @escaping (EarnPortfolio, Bool) -> EarnPortfolioSectionState,
        analyticsProvider: AnalyticsProvider,
        limitModel: WalletSectionLimitModel
    ) {
        self.wallet = wallet
        self.isEnabled = isEnabled
        self.store = store
        self.balanceLoader = balanceLoader
        self.mapper = mapper
        self.analyticsProvider = analyticsProvider
        self.limitModel = limitModel

        limitSubscription = limitModel.limitChanges.sink { [weak self] _ in
            self?.update()
        }

        store.addObserver(self) { observer, event in
            switch event {
            case let .didUpdatePortfolio(wallet):
                Task { @MainActor in
                    guard observer.wallet == wallet else { return }
                    observer.update()
                }
            }
        }
        appSettingsStore.addObserver(self) { observer, event in
            guard case .didUpdateIsSecureMode = event else { return }
            Task { @MainActor in
                observer.update()
            }
        }
        update()
    }

    /// A wallet can finish syncing its multichain wallet after the screen opened. A balance run in
    /// flight read it before that and loaded nothing for it, so the change is reported the way a
    /// streamed one is: at a priority that earns a run of its own after that one.
    func adopt(wallet: Wallet) {
        guard self.wallet == wallet else { return }
        let previousEarnWalletId = self.wallet.earnWalletId
        self.wallet = wallet
        update()
        guard state == .loading, wallet.earnWalletId != previousEarnWalletId else { return }
        reload(priority: .background)
    }

    func reload() {
        reload(priority: .userInitiated)
    }

    func positionsDidAppear() {
        guard !isPositionsViewReported, let portfolio, !portfolio.positions.isEmpty else { return }
        isPositionsViewReported = true
        analyticsProvider.log(
            EarnEntryView(
                from: .earnYourVaults,
                vaultsCount: portfolio.positions.count,
                balanceUsd: portfolio.totalFiat[Currency.USD.code].map { NSDecimalNumber(decimal: $0).doubleValue }
            )
        )
    }

    func positionsDidDisappear() {
        isPositionsViewReported = false
    }

    func openCatalog() {
        onOpenCatalog?()
    }

    func selectLimit(_ limit: WalletSectionLimit) {
        limitModel.select(limit)
    }

    func selectRow(id: String) {
        guard let position = portfolio?.positions.first(where: { $0.rowId == id }) else { return }
        onSelectPosition?(position)
    }

    private func reload(priority: BalanceRefreshPriority) {
        Task { [balanceLoader, wallet] in
            await balanceLoader.reloadBalance(wallet: wallet, priority: priority)
        }
    }

    private func update() {
        guard isEnabled, wallet.earnWalletId != nil else {
            portfolio = nil
            state = .disabled
            return
        }
        switch store.portfolioState(wallet: wallet) {
        case .none:
            portfolio = nil
            state = .loading
        case .unavailable:
            portfolio = nil
            state = .unavailable
        case let .loaded(portfolio, isStale):
            self.portfolio = portfolio
            state = portfolio.positions.isEmpty
                ? .empty
                : .positions(mapper(portfolio, isStale).limited(to: limitModel.limit))
        }
    }
}
