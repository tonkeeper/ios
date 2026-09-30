import Foundation
import KeeperCore
import TKCore
import TKUIKit

@MainActor
final class MultichainWalletBalanceSectionViewModel: ObservableObject {
    @Published private(set) var config: BalanceViewConfig = .shimmer

    var onAddress: ((Wallet) -> Void)?
    var onBattery: ((Wallet) -> Void)?
    var onBackup: ((Wallet) -> Void)?
    /// The amount is the wallet's asset listing, which the screen owns: this asks it for one.
    var onNeedsTotalRefresh: (() -> Void)?

    private(set) var wallet: Wallet

    private let totalBalanceModel: WalletTotalBalanceModel
    private let balanceLoader: BalanceLoader
    private let portfolioStore: MultichainPortfolioStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let headerMapper: WalletBalanceHeaderMapper
    private let configuration: Configuration
    private let freshnessModel = BalanceFreshnessModel()
    private let portfolioFormatting = MultichainPortfolioAmountFormatting()

    /// Starts pending: nothing has answered for this wallet yet, and the first frame must not
    /// claim there is nothing to show.
    private var isTotalPending = true

    init(
        wallet: Wallet,
        totalBalanceModel: WalletTotalBalanceModel,
        balanceLoader: BalanceLoader,
        walletsStore: WalletsStore,
        portfolioStore: MultichainPortfolioStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        headerMapper: WalletBalanceHeaderMapper,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.totalBalanceModel = totalBalanceModel
        self.balanceLoader = balanceLoader
        self.portfolioStore = portfolioStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.headerMapper = headerMapper
        self.configuration = configuration

        totalBalanceModel.didUpdateState = { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }

        freshnessModel.didUpdateFreshness = { [weak self] _ in
            self?.update()
        }

        freshnessModel.onNeedsRefresh = { [weak self] in
            self?.refresh()
        }

        // The total is written for every wallet by the wallets-list sweep, not only by this
        // screen's own listing, so the store is what the section follows.
        portfolioStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdatePortfolio(wallet):
                Task { @MainActor in
                    observer.didUpdatePortfolio(wallet: wallet)
                }
            }
        }

        walletsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                observer.didGetWalletsStoreEvent(event)
            }
        }

        update()
    }

    func didAppear() {
        freshnessModel.didAppear()
    }

    func didDisappear() {
        freshnessModel.didDisappear()
    }

    /// The amount, the battery and the backup warning are rendered from a cache that outlives the
    /// launch, so an appearance and a return from the background both ask for the loads that
    /// confirm them.
    private func refresh() {
        Task { [balanceLoader, wallet] in
            await balanceLoader.reloadBalance(wallet: wallet, priority: .userVisible)
        }
        onNeedsTotalRefresh?()
    }

    func reload() async {
        await balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
    }

    /// The amount is produced by the wallet's asset listing rather than by this section, so the
    /// screen says whether it is still waiting for one. A wallet whose total is already known keeps
    /// rendering it while the listing refreshes.
    func setTotalPending(_ isPending: Bool) {
        guard isTotalPending != isPending else { return }
        isTotalPending = isPending
        update()
    }

    func balancePressed() {
        appSettingsStore.toggleIsSecureMode()
    }

    func addressPressed() {
        onAddress?(wallet)
    }

    func addressLongPressed() {
        guard let address = wallet.multichainAddress(for: .ton) else { return }
        Pasteboard.copy(value: address, toast: .copied.withPlacement(.navigationBar))
    }

    func batteryPressed() {
        onBattery?(wallet)
    }

    func backupPressed() {
        onBackup?(wallet)
    }

    /// The store is only written when a listing answered for the wallet, so its update is what
    /// makes the amount current again.
    private func didUpdatePortfolio(wallet: Wallet) {
        guard self.wallet == wallet else { return }
        freshnessModel.markFresh()
        update()
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        switch event {
        case let .didUpdateWalletMetaData(wallet),
             let .didUpdateWalletSetupSettings(wallet),
             let .didUpdateWalletBatterySettings(wallet),
             let .didUpdateWalletMultichain(wallet):
            adopt(wallet: wallet)
        default:
            break
        }
    }

    /// The backup warning and the battery ride on the wallet value, so the section takes every
    /// update to its own wallet rather than keeping the value it was created with.
    private func adopt(wallet: Wallet) {
        guard self.wallet == wallet else { return }
        self.wallet = wallet
        update()
    }

    private func update() {
        guard let state = try? totalBalanceModel.getState() else {
            return setConfig(.content(BalanceViewContent(balance: BalanceViewContent.Balance(text: "-"))))
        }
        let portfolioTotal = portfolioTotal()
        if portfolioTotal == nil, isTotalPending {
            return setConfig(.shimmer)
        }
        setConfig(
            BalanceSwiftUIMapper.balanceViewConfig(
                portfolioTotal: portfolioTotal,
                wallet: wallet,
                state: state,
                freshness: freshnessModel.freshness,
                headerMapper: headerMapper,
                configuration: configuration
            )
        )
    }

    private func portfolioTotal() -> (amount: Decimal, currency: Currency)? {
        guard let total = portfolioStore.getState()[wallet] else { return nil }
        return portfolioFormatting.portfolioFiatTotalAndCurrency(
            from: total.fiatPrice,
            displayCurrency: currencyStore.getState()
        )
    }

    private func setConfig(_ config: BalanceViewConfig) {
        guard self.config != config else { return }
        self.config = config
    }
}
