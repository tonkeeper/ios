import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

@MainActor
final class MultichainWalletViewModel: ObservableObject {
    let balanceViewModel: MultichainWalletBalanceSectionViewModel
    let homeBannersViewModel: WalletBalanceHomeBannersViewModel
    let assetsListViewModel: WalletBalanceMultichainAssetsListViewModel
    let collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel

    enum FinishSetup: Equatable {
        case hidden
        case visible(items: [WalletBalanceSetupModel.State.Item], isSkippable: Bool)
    }

    enum State {
        case pending
        case ready(
            iconButtons: MultichainWalletIconButtonsModel,
            finishSetup: FinishSetup
        )
    }

    @Published private(set) var state: State = .pending

    var onSend: ((Wallet) -> Void)?
    var onDeposit: ((Wallet) -> Void)?
    var onSwap: ((Wallet) -> Void)?
    var onStake: ((Wallet) -> Void)?
    var onBackup: ((Wallet) -> Void)?
    var onMigration: ((Wallet) -> Void)?
    var onRequirePasscode: (() async -> String?)?

    private(set) var wallet: Wallet

    private let setupModel: WalletBalanceSetupModel
    private let configuration: Configuration
    private let tooltipsService: TooltipsService
    private let syncStatusPoller: MultichainWalletSyncStatusPoller

    private enum FirstLoad {
        case pending(generation: Int)
        case answered(generation: Int)

        var generation: Int {
            switch self {
            case let .pending(generation), let .answered(generation):
                generation
            }
        }
    }

    private var firstLoad: FirstLoad = .pending(generation: 0)
    private var iconButtons: MultichainWalletIconButtonsModel
    private var finishSetup: FinishSetup = .hidden

    private var isActive = true
    private var isOnScreen = false
    private var isAssetsReloadScheduled = false
    private var needsAssetsReload = false
    private var reloadAssetsTask: Task<Void, Never>?
    private var reloadAssetsState = MultichainWalletAssetsReloadScheduling.State()

    init(
        wallet: Wallet,
        balanceViewModel: MultichainWalletBalanceSectionViewModel,
        homeBannersViewModel: WalletBalanceHomeBannersViewModel,
        assetsListViewModel: WalletBalanceMultichainAssetsListViewModel,
        collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel,
        setupModel: WalletBalanceSetupModel,
        walletsStore: WalletsStore,
        multichainService: MultichainService,
        realtimeManager: MultichainRealtimeManager?,
        balanceLoader: BalanceLoader,
        stakingPoolsStore: StakingPoolsStore,
        processedBalanceStore: ProcessedBalanceStore,
        configuration: Configuration,
        tooltipsService: TooltipsService
    ) {
        self.wallet = wallet
        self.balanceViewModel = balanceViewModel
        self.homeBannersViewModel = homeBannersViewModel
        self.assetsListViewModel = assetsListViewModel
        self.collectiblesViewModel = collectiblesViewModel
        self.setupModel = setupModel
        self.configuration = configuration
        iconButtons = Self.iconButtonsModel(wallet: wallet, configuration: configuration)
        finishSetup = Self.finishSetup(for: setupModel.getState())
        self.tooltipsService = tooltipsService
        self.syncStatusPoller = MultichainWalletSyncStatusPoller(
            wallet: wallet,
            multichainService: multichainService
        )

        syncStatusPoller.onSyncStatusUpdate = { [weak self] in
            await self?.reloadAssets(startsSyncStatusPolling: false)
        }

        assetsListViewModel.onRetry = { [weak self] in
            self?.retryInitialLoad()
        }

        assetsListViewModel.onNeedsReload = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.reloadAssets(startsSyncStatusPolling: false)
            }
        }

        balanceViewModel.onNeedsTotalRefresh = { [weak self] in
            self?.requestAssetsReload()
        }

        balanceLoader.addUpdateObserver(self) { observer, update in
            Task { @MainActor in
                observer.didGetBalanceLoaderUpdate(update)
            }
        }

        realtimeManager?.addBalanceChangeObserver(self) { observer, walletId in
            Task { @MainActor in
                guard observer.wallet.multichainWalletState?.walletId == walletId else { return }
                await observer.reloadAssets(startsSyncStatusPolling: false)
            }
        }

        stakingPoolsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case let .didUpdateStakingPools(wallet):
                    guard observer.wallet == wallet else { return }
                    observer.assetsListViewModel.refreshPresentation()
                }
            }
        }

        processedBalanceStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case let .didUpdateProccessedBalance(wallet):
                    guard observer.wallet == wallet else { return }
                    observer.assetsListViewModel.refreshPresentation()
                }
            }
        }

        walletsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                observer.didGetWalletsStoreEvent(event)
            }
        }

        setupModel.didUpdateState = { [weak self] state in
            Task { @MainActor in
                self?.applyFinishSetupState(state)
            }
        }

        if assetsListViewModel.restoreCachedAssets() {
            firstLoad = .answered(generation: firstLoad.generation)
        }
        updateState()
    }

    deinit {
        reloadAssetsTask?.cancel()
    }

    func didAppear() {
        isOnScreen = true
        balanceViewModel.didAppear()
    }

    func didDisappear() {
        isOnScreen = false
        balanceViewModel.didDisappear()
    }

    func resignActive() {
        isActive = false
        isOnScreen = false
        balanceViewModel.didDisappear()
        assetsListViewModel.setActive(false)
        collectiblesViewModel.setActive(false)
        syncStatusPoller.stop()
        reloadAssetsTask?.cancel()
    }

    func becomeActive(isVisible: Bool) {
        isActive = true
        isOnScreen = isVisible
        assetsListViewModel.setActive(true)
        collectiblesViewModel.setActive(true)
        scheduleAssetsReload(startsSyncStatusPolling: true)
    }

    func refresh() async {
        reloadBalance()
        await reloadAssets()
    }

    func reloadAssets() async {
        await reloadAssets(startsSyncStatusPolling: true)
    }

    func applyVisibilityUpdate(_ update: TokenManagementVisibilityUpdate) async {
        assetsListViewModel.applyVisibilityUpdate(update)
        await reloadAssets(startsSyncStatusPolling: false)
    }

    func retryInitialLoad() {
        guard isActive else { return }
        firstLoad = .pending(generation: firstLoad.generation + 1)
        updateState()
        Task { [weak self] in
            await self?.reloadAssets()
        }
    }

    func backupPressed() {
        onBackup?(wallet)
    }

    func migrationPressed() {
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

    func skipSetup() {
        setupModel.finishSetup()
    }

    func tapSend() {
        tooltipsService.didPerformTooltipTargetAction(id: .walletBalanceWithdraw)
        onSend?(wallet)
    }

    func tapDeposit() {
        onDeposit?(wallet)
    }

    func tapSwap() {
        onSwap?(wallet)
    }

    func tapStake() {
        onStake?(wallet)
    }

    private func reloadBalance() {
        Task { [balanceViewModel] in
            await balanceViewModel.reload()
        }
    }

    private func requestAssetsReload() {
        guard isActive, !isAssetsReloadScheduled else { return }
        guard reloadAssetsTask == nil else {
            needsAssetsReload = true
            return
        }
        scheduleAssetsReload(startsSyncStatusPolling: true)
    }

    private func scheduleAssetsReload(startsSyncStatusPolling: Bool) {
        isAssetsReloadScheduled = true
        Task { @MainActor [weak self] in
            await self?.reloadAssets(startsSyncStatusPolling: startsSyncStatusPolling)
        }
    }

    private func reloadAssets(startsSyncStatusPolling: Bool) async {
        isAssetsReloadScheduled = false
        guard isActive else { return }
        reloadAssetsTask?.cancel()
        let request = reloadAssetsState.makeRequest(startsSyncStatusPolling: startsSyncStatusPolling)
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
        if needsAssetsReload {
            scheduleAssetsReload(startsSyncStatusPolling: false)
        }
    }

    private func performReloadAssets(request: MultichainWalletAssetsReloadScheduling.Request) async {
        guard !Task.isCancelled, reloadAssetsState.isCurrent(request) else { return }
        let firstLoadGeneration = pendingGeneration

        if isOnScreen {
            balanceViewModel.didAppear()
        }
        refreshIconButtons()
        balanceViewModel.setTotalPending(true)
        homeBannersViewModel.startLoadIfNeeded()
        needsAssetsReload = false
        async let assetsLoad: Void = assetsListViewModel.loadAssets()
        async let collectiblesLoad: Void = collectiblesViewModel.load()
        await assetsLoad
        if !Task.isCancelled, reloadAssetsState.isCurrent(request) {
            balanceViewModel.setTotalPending(false)
        }
        await collectiblesLoad
        guard !Task.isCancelled, reloadAssetsState.isCurrent(request) else { return }
        if let firstLoadGeneration {
            markFirstLoadAnswered(generation: firstLoadGeneration)
        }
        if reloadAssetsState.consumePollingRequirement(for: request) {
            syncStatusPoller.restart()
        }
    }

    private var pendingGeneration: Int? {
        guard case let .pending(generation) = firstLoad else { return nil }
        return generation
    }

    private func markFirstLoadAnswered(generation: Int) {
        guard case let .pending(current) = firstLoad, current == generation else { return }
        firstLoad = .answered(generation: generation)
        updateState()
    }

    private func updateState() {
        switch firstLoad {
        case .pending:
            state = .pending
        case .answered:
            state = .ready(iconButtons: iconButtons, finishSetup: finishSetup)
        }
    }

    private func didGetBalanceLoaderUpdate(_ update: BalanceLoaderUpdate) {
        guard wallet == update.wallet, update.result != nil else { return }
        assetsListViewModel.refreshPresentation()
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        switch event {
        case let .didUpdateWalletMetaData(wallet),
             let .didUpdateWalletSetupSettings(wallet),
             let .didUpdateWalletBatterySettings(wallet):
            adopt(wallet: wallet)
        case let .didUpdateWalletMultichain(wallet):
            guard adopt(wallet: wallet), isActive else { return }
            Task { [weak self] in
                await self?.reloadAssets()
            }
        default:
            break
        }
    }

    @discardableResult
    private func adopt(wallet: Wallet) -> Bool {
        guard self.wallet == wallet else { return false }
        self.wallet = wallet
        assetsListViewModel.adopt(wallet: wallet)
        syncStatusPoller.adopt(wallet: wallet)
        refreshIconButtons()
        return true
    }

    private func applyFinishSetupState(_ state: WalletBalanceSetupModel.State?) {
        let finishSetup = Self.finishSetup(for: state)
        guard self.finishSetup != finishSetup else { return }
        self.finishSetup = finishSetup
        updateState()
    }

    private static func finishSetup(for state: WalletBalanceSetupModel.State?) -> FinishSetup {
        guard let state, !state.items.isEmpty else { return .hidden }
        return .visible(items: state.items, isSkippable: state.isFinishEnable)
    }

    private func refreshIconButtons() {
        let iconButtons = Self.iconButtonsModel(wallet: wallet, configuration: configuration)
        guard self.iconButtons != iconButtons else { return }
        self.iconButtons = iconButtons
        updateState()
    }

    private static func iconButtonsModel(
        wallet: Wallet,
        configuration: Configuration
    ) -> MultichainWalletIconButtonsModel {
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

        return MultichainWalletIconButtonsModel(
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
    }
}

enum MultichainWalletAssetsReloadScheduling {
    struct Request {
        let generation: Int
        let startsSyncStatusPolling: Bool
    }

    struct State {
        private var generation = 0
        private var startsSyncStatusPolling = false

        mutating func makeRequest(startsSyncStatusPolling: Bool) -> Request {
            generation += 1
            self.startsSyncStatusPolling = self.startsSyncStatusPolling || startsSyncStatusPolling
            return Request(generation: generation, startsSyncStatusPolling: self.startsSyncStatusPolling)
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
