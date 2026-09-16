import Combine
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class MultichainWalletRootViewModel: ObservableObject {
    enum FinishSetupItem: Identifiable, Equatable {
        case backup
        case migration(walletsLeft: Int)
        case notifications
        case biometry

        var id: String {
            switch self {
            case .backup: "backup"
            case .migration: "migration"
            case .notifications: "notifications"
            case .biometry: "biometry"
            }
        }
    }

    let assetsListViewModel: WalletBalanceMultichainAssetsListViewModel
    let collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel
    let tooltipsService: TooltipsService

    @Published private(set) var balanceViewModel: MultichainWalletBalanceSectionViewModel
    @Published private(set) var homeBannersViewModel: WalletBalanceHomeBannersViewModel
    @Published private(set) var iconButtonsModel: MultichainWalletIconButtonsModel?
    @Published private(set) var showsSkeleton = true
    @Published private(set) var rafflePresentation: MysteryRafflePresentation?
    @Published private(set) var finishSetupItems: [FinishSetupItem] = []
    @Published private(set) var isFinishSetupEnabled = false

    var showsFinishSetup: Bool {
        !finishSetupItems.isEmpty
    }

    var onSend: ((Wallet) -> Void)?

    var onDeposit: ((Wallet) -> Void)?
    var onSwap: ((Wallet) -> Void)?
    var onStake: ((Wallet) -> Void)?
    var onBackup: ((Wallet) -> Void)?
    var onMigration: ((Wallet) -> Void)?
    var onRequirePasscode: (() async -> String?)?
    var onOpenRaffle: (() -> Void)?

    var didChangeWallet: (() -> Void)?

    private let walletsStore: WalletsStore
    private let setupModel: WalletBalanceSetupModel
    private let multichainService: MultichainService
    private let realtimeManager: MultichainRealtimeManager?
    private var raffleObserver: MysteryRafflePresentationObserver?
    private let analyticsProvider: AnalyticsProvider
    private let configuration: Configuration
    private let syncStatusPoller: MultichainWalletSyncStatusPoller
    private let makeHomeBannersViewModel: (Wallet) -> WalletBalanceHomeBannersViewModel
    private var homeBannersViewModels = [HomeBannersIdentity: WalletBalanceHomeBannersViewModel]()

    private let makeBalanceViewModel: (Wallet) -> MultichainWalletBalanceSectionViewModel
    private var balanceViewModels = [String: MultichainWalletBalanceSectionViewModel]()

    private var lastWalletId: String?
    private var isOnScreen = false
    private var finishSetupWallet: Wallet?
    private var skeletonGeneration = 0
    private var reloadAssetsTask: Task<Void, Never>?
    private var reloadAssetsState = MultichainWalletAssetsReloadScheduling.State()

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        setupModel: WalletBalanceSetupModel,
        balanceLoader: BalanceLoader,
        multichainService: MultichainService,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider,
        currencyStore: CurrencyStore,
        amountFormatter: AmountFormatter,
        configuration: Configuration,
        tooltipsService: TooltipsService,
        appSettingsStore: AppSettingsStore,
        makeBalanceViewModel: @escaping (Wallet) -> MultichainWalletBalanceSectionViewModel,
        storesAssembly: StoresAssembly,
        accountNftService: AccountNFTService,
        makeHomeBannersViewModel: @escaping (Wallet) -> WalletBalanceHomeBannersViewModel,
        raffleStore: RaffleStore,
        analyticsProvider: AnalyticsProvider,
        realtimeManager: MultichainRealtimeManager? = nil
    ) {
        self.walletsStore = walletsStore
        self.setupModel = setupModel
        self.multichainService = multichainService
        self.realtimeManager = realtimeManager
        self.analyticsProvider = analyticsProvider
        self.configuration = configuration
        self.tooltipsService = tooltipsService
        self.makeBalanceViewModel = makeBalanceViewModel
        let balanceViewModel = makeBalanceViewModel(wallet)
        balanceViewModels = [wallet.id: balanceViewModel]
        self.balanceViewModel = balanceViewModel
        self.makeHomeBannersViewModel = makeHomeBannersViewModel
        let homeBannersViewModel = makeHomeBannersViewModel(wallet)
        homeBannersViewModels = [HomeBannersIdentity(wallet: wallet): homeBannersViewModel]
        self.homeBannersViewModel = homeBannersViewModel
        self.collectiblesViewModel = WalletBalanceMultichainCollectiblesViewModel(
            storesAssembly: storesAssembly,
            accountNftService: accountNftService,
            appSettingsStore: appSettingsStore
        )
        self.assetsListViewModel = WalletBalanceMultichainAssetsListViewModel(
            multichainService: multichainService,
            multichainAssetBalanceProvider: multichainAssetBalanceProvider,
            currencyStore: currencyStore,
            amountFormatter: amountFormatter,
            portfolioStore: storesAssembly.multichainPortfolioStore,
            stakingPoolsStore: storesAssembly.stackingPoolsStore,
            processedBalanceStore: storesAssembly.processedBalanceStore,
            appSettingsStore: appSettingsStore,
            tonStakingAPYProvider: { [configuration, storesAssembly] wallet in
                guard !configuration.flag(\.stakingDisabled, network: wallet.network) else {
                    return nil
                }
                return storesAssembly.stackingPoolsStore.state[wallet]?
                    .filter { configuration.value(\.stakingEnabledProviders).contains($0.implementation.type.rawValue) }
                    .map(\.apy)
                    .max()
            },
            tonStakingAPYTextFormatter: { [amountFormatter] value in
                guard let value else { return nil }
                return TKLocales.Trade.AssetDetails.apyValue(
                    amountFormatter.format(decimal: value, style: .percent)
                )
            },
            canManage: true
        )
        self.syncStatusPoller = MultichainWalletSyncStatusPoller(
            walletsStore: walletsStore,
            multichainService: multichainService
        )

        syncStatusPoller.onSyncStatusUpdate = { [weak self] in
            await self?.reloadAssets(startsSyncStatusPolling: false)
        }

        assetsListViewModel.onRetry = { [weak self] in
            self?.retryInitialLoad()
        }

        balanceLoader.addUpdateObserver(self) { observer, update in
            Task { @MainActor in
                observer.didGetBalanceLoaderUpdate(update)
            }
        }

        raffleObserver = MysteryRafflePresentationObserver(
            raffleStore: raffleStore,
            isFeatureEnabled: configuration.featureEnabled(.mysteryRaffleEnabled)
        ) { [weak self] presentation in
            self?.rafflePresentation = presentation
        }

        realtimeManager?.addBalanceChangeObserver(self) { observer, walletId in
            Task { @MainActor in
                guard observer.balanceViewModel.wallet.multichainWalletState?.walletId == walletId else { return }
                await observer.reloadAssets(startsSyncStatusPolling: false)
            }
        }

        storesAssembly.stackingPoolsStore.addObserver(self) { [weak self] _, event in
            guard let self else { return }
            Task { @MainActor in
                switch event {
                case let .didUpdateStakingPools(wallet):
                    guard self.isActiveWallet(wallet) else { return }
                    self.assetsListViewModel.refreshPresentation()
                }
            }
        }

        storesAssembly.processedBalanceStore.addObserver(self) { [weak self] _, event in
            guard let self else { return }
            Task { @MainActor in
                switch event {
                case let .didUpdateProccessedBalance(wallet):
                    guard self.isActiveWallet(wallet) else { return }
                    self.assetsListViewModel.refreshPresentation()
                }
            }
        }

        walletsStore.addObserver(self) { [weak self] _, event in
            guard let self else { return }
            Task { @MainActor in
                switch event {
                case .didChangeActiveWallet:
                    self.didChangeWallet?()
                    await self.reloadAssets()
                case .didUpdateWalletMetaData,
                     .didUpdateWalletSetupSettings:
                    await self.reloadAssets()
                case let .didUpdateWalletMultichain(wallet):
                    guard self.isActiveWallet(wallet) else { return }
                    await self.reloadAssets()
                default:
                    break
                }
            }
        }

        setupModel.didUpdateState = { [weak self] state in
            Task { @MainActor in
                self?.applyFinishSetupState(state)
            }
        }

        bindBalanceViewModel()
        refreshIconButtonsModel()
        applyFinishSetupState(setupModel.getState())
    }

    func viewWillAppear() {
        isOnScreen = true
        balanceViewModel.didAppear()
    }

    func viewDidDisappear() {
        isOnScreen = false
        balanceViewModel.didDisappear()
    }

    func reloadData() {
        Task { [balanceViewModel] in
            await balanceViewModel.reload()
        }
    }

    func refresh() async {
        reloadData()
        await reloadAssets()
    }

    func reloadAssets() async {
        await reloadAssets(startsSyncStatusPolling: true)
    }

    func reloadAssetsList() async {
        let wallet = try? walletsStore.activeWallet
        await assetsListViewModel.loadAssets(for: wallet)
    }

    func retryInitialLoad() {
        skeletonGeneration += 1
        showsSkeleton = true
        Task { [weak self] in
            await self?.reloadAssets()
        }
    }

    private func reloadAssets(startsSyncStatusPolling: Bool) async {
        reloadAssetsTask?.cancel()
        let request = reloadAssetsState.makeRequest(
            startsSyncStatusPolling: startsSyncStatusPolling
        )
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performReloadAssets(request: request)
        }
        reloadAssetsTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        guard reloadAssetsState.isCurrent(request) else { return }
        reloadAssetsTask = nil
        if task.isCancelled {
            reloadAssetsState.cancel(request)
        }
    }

    private func performReloadAssets(request: MultichainWalletAssetsReloadScheduling.Request) async {
        let wallet = try? walletsStore.activeWallet
        updateHomeBannersViewModel(wallet: wallet)
        updateBalanceViewModel(wallet: wallet)
        if wallet?.id != lastWalletId {
            lastWalletId = wallet?.id
            skeletonGeneration += 1
            showsSkeleton = true
        }
        let currentSkeletonGeneration = skeletonGeneration

        refreshIconButtonsModel(wallet: wallet)
        balanceViewModel.setTotalPending(true)
        async let assetsLoad: Void = assetsListViewModel.loadAssets(for: wallet)
        async let collectiblesLoad: Void = collectiblesViewModel.load(for: wallet)
        // The amount rides on the listing alone, so the wait the balance renders ends there rather
        // than with the rest of the screen. A superseded run leaves it to the one that replaced it.
        await assetsLoad
        if reloadAssetsState.isCurrent(request) {
            balanceViewModel.setTotalPending(false)
        }
        await collectiblesLoad
        guard !Task.isCancelled, reloadAssetsState.isCurrent(request) else { return }
        if reloadAssetsState.consumePollingRequirement(for: request) {
            syncStatusPoller.restart(for: wallet)
        }

        guard !Task.isCancelled, currentSkeletonGeneration == skeletonGeneration else { return }
        if showsSkeleton {
            showsSkeleton = false
        }
    }

    func backupPressed() {
        guard let wallet = try? walletsStore.activeWallet else { return }
        onBackup?(wallet)
    }

    func migrationPressed() {
        guard let wallet = try? walletsStore.activeWallet else { return }
        onMigration?(wallet)
    }

    func enableNotifications() {
        Task { await setupModel.turnOnNotifications() }
    }

    func enableBiometry() {
        Task {
            guard let passcode = await onRequirePasscode?() else { return }
            do {
                try await setupModel.turnOnBiometry(passcode: passcode)
            } catch {
                ToastPresenter.showToast(configuration: .failed)
            }
        }
    }

    func finishSetup() {
        guard let wallet = finishSetupWallet else { return }
        setupModel.finishSetup(for: wallet)
    }

    func tapSend() {
        guard let wallet = try? walletsStore.activeWallet else { return }
        tooltipsService.didPerformTooltipTargetAction(id: .walletBalanceWithdraw)
        onSend?(wallet)
    }

    func tapDeposit() {
        guard let wallet = try? walletsStore.activeWallet else { return }
        onDeposit?(wallet)
    }

    func tapSwap() {
        guard let wallet = try? walletsStore.activeWallet else { return }
        onSwap?(wallet)
    }

    func tapRaffle() {
        analyticsProvider.log(RaffleBannerClick(source: .walletMain))
        onOpenRaffle?()
    }

    func raffleBannerDidAppear() {
        guard rafflePresentation?.shouldShowMainScreenEntry == true else { return }
        analyticsProvider.log(RaffleBannerView(source: .walletMain))
    }

    func tapStake() {
        guard let wallet = try? walletsStore.activeWallet else { return }
        onStake?(wallet)
    }

    /// The total it renders, the wallet value it reads and the reload it asks for all belong to
    /// one wallet, so a switch takes that wallet's model rather than re-pointing this one.
    private func updateBalanceViewModel(wallet: Wallet?) {
        guard let wallet else { return }
        let viewModel = balanceViewModel(for: wallet)
        if viewModel !== balanceViewModel {
            // A section kept for a wallet nobody is looking at must not keep asking for the loads
            // that a visible one is entitled to.
            balanceViewModel.onNeedsTotalRefresh = nil
            balanceViewModel.didDisappear()
            balanceViewModel = viewModel
            bindBalanceViewModel()
        }
        if isOnScreen {
            viewModel.didAppear()
        }
    }

    private func bindBalanceViewModel() {
        balanceViewModel.onNeedsTotalRefresh = { [weak self] in
            // A reload already under way answers the request, and replacing it would drop the
            // listing it has in flight — including the one a wallet switch is running right now.
            guard let self, self.reloadAssetsTask == nil else { return }
            Task { @MainActor [weak self] in
                await self?.reloadAssets()
            }
        }
    }

    private func balanceViewModel(for wallet: Wallet) -> MultichainWalletBalanceSectionViewModel {
        if let viewModel = balanceViewModels[wallet.id] {
            return viewModel
        }

        let viewModel = makeBalanceViewModel(wallet)
        balanceViewModels[wallet.id] = viewModel
        return viewModel
    }

    /// One model per wallet: the deck it renders, the dismissals it writes and the scope it
    /// reloads all belong to that wallet alone. Without a wallet there is nothing to re-point it
    /// to, and the screen is on its way out anyway, so it keeps the deck it is showing.
    private func updateHomeBannersViewModel(wallet: Wallet?) {
        guard let wallet else { return }
        let viewModel = homeBannersViewModel(for: wallet)
        if viewModel !== homeBannersViewModel {
            homeBannersViewModel = viewModel
        }
        viewModel.loadIfNeeded()
    }

    private func homeBannersViewModel(for wallet: Wallet) -> WalletBalanceHomeBannersViewModel {
        let identity = HomeBannersIdentity(wallet: wallet)
        if let viewModel = homeBannersViewModels[identity] {
            return viewModel
        }

        let viewModel = makeHomeBannersViewModel(wallet)
        homeBannersViewModels[identity] = viewModel
        return viewModel
    }

    private func refreshIconButtonsModel(wallet: Wallet? = nil) {
        let resolved = wallet ?? (try? walletsStore.activeWallet)
        guard let wallet = resolved else {
            iconButtonsModel = nil
            return
        }

        let swapItem: MultichainWalletIconButtonsModel.Item? = {
            guard !configuration.flag(\.isSwapDisable, network: wallet.network) else { return nil }
            return MultichainWalletIconButtonsModel.Item(
                title: TKLocales.WalletButtons.swap,
                kind: .swap,
                isEnabled: wallet.isSwapEnable
            )
        }()

        let stakeItem: MultichainWalletIconButtonsModel.Item? = {
            guard !configuration.flag(\.stakingDisabled, network: wallet.network) else { return nil }
            return MultichainWalletIconButtonsModel.Item(
                title: TKLocales.WalletButtons.stake,
                kind: .stake,
                isEnabled: wallet.isStakeEnable
            )
        }()

        let model = MultichainWalletIconButtonsModel(
            send: MultichainWalletIconButtonsModel.Item(
                title: TKLocales.WalletButtons.send,
                kind: .send,
                isEnabled: wallet.isSendEnable
            ),
            deposit: MultichainWalletIconButtonsModel.Item(
                title: TKLocales.WalletButtons.deposit,
                kind: .deposit,
                isEnabled: wallet.isReceiveEnable
            ),
            swap: swapItem,
            stake: stakeItem
        )
        if iconButtonsModel != model {
            iconButtonsModel = model
        }
    }

    /// A result rather than a start edge: the run has landed and the list has something to read.
    private func didGetBalanceLoaderUpdate(_ update: BalanceLoaderUpdate) {
        guard isActiveWallet(update.wallet), update.result != nil else { return }
        assetsListViewModel.refreshPresentation()
    }

    private func applyFinishSetupState(_ state: WalletBalanceSetupModel.State?) {
        finishSetupWallet = state?.wallet
        let isBiometryAvailable = BiometryProvider().isAvailable
        let items: [FinishSetupItem] = (state?.items ?? []).compactMap { item in
            switch item {
            case .backup: .backup
            case let .migration(walletsLeft): .migration(walletsLeft: walletsLeft)
            case .notifications: .notifications
            case .biometry: isBiometryAvailable ? .biometry : nil
            }
        }
        if finishSetupItems != items {
            finishSetupItems = items
        }
        let isFinishEnabled = state?.isFinishEnable ?? false
        if isFinishSetupEnabled != isFinishEnabled {
            isFinishSetupEnabled = isFinishEnabled
        }

        if items.isEmpty,
           let wallet = state?.wallet,
           !wallet.setupSettings.isSetupFinished
        {
            setupModel.finishSetup(for: wallet)
        }
    }

    private func isActiveWallet(_ wallet: Wallet) -> Bool {
        guard let activeWallet = try? walletsStore.activeWallet else {
            return false
        }
        return activeWallet == wallet
    }
}

enum MultichainWalletAssetsReloadScheduling {
    struct Request: Equatable {
        let generation: Int
        let startsSyncStatusPolling: Bool
    }

    struct State {
        private var generation = 0
        private var startsSyncStatusPolling = false

        mutating func makeRequest(startsSyncStatusPolling: Bool) -> Request {
            generation += 1
            self.startsSyncStatusPolling = self.startsSyncStatusPolling || startsSyncStatusPolling
            return Request(
                generation: generation,
                startsSyncStatusPolling: self.startsSyncStatusPolling
            )
        }

        func isCurrent(_ request: Request) -> Bool {
            request.generation == generation
        }

        mutating func consumePollingRequirement(for request: Request) -> Bool {
            guard isCurrent(request) else { return false }
            startsSyncStatusPolling = false
            return request.startsSyncStatusPolling
        }

        mutating func cancel(_ request: Request) {
            guard isCurrent(request) else { return }
            startsSyncStatusPolling = false
        }
    }
}
