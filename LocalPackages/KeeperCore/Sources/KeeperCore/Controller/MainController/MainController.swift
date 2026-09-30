import Foundation
import TonSwift

public final class MainController {
    public var didReceiveTonConnectRequest: ((TonConnect.AppRequest, Wallet, TonConnectApp) -> Void)?

    private let backgroundUpdate: BackgroundUpdate
    private let tonConnectEventsStore: TonConnectEventsStore
    private let tonConnectService: TonConnectService
    private let deeplinkParser: DeeplinkParser

    private let walletsStore: WalletsStore
    private let balanceLoader: BalanceLoader
    private let walletInfoLoader: WalletInfoLoader

    private let internalNotificationsLoader: InternalNotificationsLoader
    private let homeBannersLoader: HomeBannersLoader
    private let tronUSDTFeesService: TronUsdtFeesService
    private let multichainRealtimeManager: MultichainRealtimeManager

    private let updatesContinuation: AsyncStream<MainControllerUpdatesCommand>.Continuation
    private var updatesWorker: Task<Void, Never>?

    init(
        backgroundUpdate: BackgroundUpdate,
        tonConnectEventsStore: TonConnectEventsStore,
        tonConnectService: TonConnectService,
        deeplinkParser: DeeplinkParser,
        walletsStore: WalletsStore,
        balanceLoader: BalanceLoader,
        internalNotificationsLoader: InternalNotificationsLoader,
        homeBannersLoader: HomeBannersLoader,
        walletInfoLoader: WalletInfoLoader,
        tronUSDTFeesService: TronUsdtFeesService,
        multichainRealtimeManager: MultichainRealtimeManager
    ) {
        self.backgroundUpdate = backgroundUpdate
        self.tonConnectEventsStore = tonConnectEventsStore
        self.tonConnectService = tonConnectService
        self.deeplinkParser = deeplinkParser
        self.balanceLoader = balanceLoader
        self.internalNotificationsLoader = internalNotificationsLoader
        self.homeBannersLoader = homeBannersLoader
        self.walletsStore = walletsStore
        self.walletInfoLoader = walletInfoLoader
        self.tronUSDTFeesService = tronUSDTFeesService
        self.multichainRealtimeManager = multichainRealtimeManager

        let (commands, updatesContinuation) = AsyncStream<MainControllerUpdatesCommand>.makeStream()
        self.updatesContinuation = updatesContinuation
        updatesWorker = nil

        let runtime = MainControllerUpdatesRuntime(
            backgroundUpdate: backgroundUpdate,
            walletsStore: walletsStore,
            balanceLoader: balanceLoader,
            walletInfoLoader: walletInfoLoader,
            tronUSDTFeesService: tronUSDTFeesService,
            multichainRealtimeManager: multichainRealtimeManager,
            tonConnectEventsStore: tonConnectEventsStore,
            tonConnectObserver: self
        )
        updatesWorker = Task {
            for await command in commands {
                await runtime.handle(command)
            }
            await runtime.shutdown()
        }

        backgroundUpdate.addEventObserver(self) { observer, wallet, _ in
            Task {
                await observer.balanceLoader.reloadBalance(wallet: wallet, priority: .background)
            }
        }

        multichainRealtimeManager.addSubscriptionObserver(self) { observer, subscribedWalletId in
            observer.balanceLoader.setRegularPollingPaused(subscribedWalletId != nil)
        }
        balanceLoader.setIsRealtimeSubscribed { [multichainRealtimeManager] walletId in
            multichainRealtimeManager.isSubscribed(walletId: walletId)
        }
    }

    deinit {
        updatesContinuation.finish()
    }

    public func start() {
        startUpdates()
        Task {
            await internalNotificationsLoader.loadNotifications(scope: .activeWallet, force: false)
        }
        Task {
            await homeBannersLoader.loadBanners(scope: .activeWallet, force: false)
        }
    }

    /// Starts updates, or refreshes the connections if they are already running.
    public func startUpdates() {
        updatesContinuation.yield(.start)
    }

    public func stopUpdates() {
        updatesContinuation.yield(.stop)
    }

    /// Re-establishes the connections after a network blip. Does nothing while updates are stopped,
    /// so a reachability event cannot bring the pipeline back up in the background.
    public func reconnectUpdates() {
        updatesContinuation.yield(.reconnect)
    }

    public func parseDeeplink(deeplink: String?) throws -> Deeplink {
        try deeplinkParser.parse(string: deeplink)
    }
}

extension MainController: TonConnectEventsStoreObserver {
    public func didGetTonConnectEventsStoreEvent(_ event: TonConnectEventsStore.Event) {
        switch event {
        case let .request(request, wallet, app):
            Task { @MainActor in
                didReceiveTonConnectRequest?(request, wallet, app)
            }
        }
    }
}

private enum MainControllerUpdatesCommand: Sendable {
    case start
    case stop
    case reconnect
}

/// Owns the desired-running state of the app-wide update pipeline. The façade only orders commands,
/// so rapid lifecycle transitions keep their order without a lock and without the main queue.
private actor MainControllerUpdatesRuntime {
    private let backgroundUpdate: BackgroundUpdate
    private let walletsStore: WalletsStore
    private let balanceLoader: BalanceLoader
    private let walletInfoLoader: WalletInfoLoader
    private let tronUSDTFeesService: TronUsdtFeesService
    private let multichainRealtimeManager: MultichainRealtimeManager
    private let tonConnectEventsStore: TonConnectEventsStore

    private var updatesStarted = false
    private weak var tonConnectObserver: TonConnectEventsStoreObserver?
    private var tonConnectTransition: Task<Void, Never>?
    private var isShutDown = false

    init(
        backgroundUpdate: BackgroundUpdate,
        walletsStore: WalletsStore,
        balanceLoader: BalanceLoader,
        walletInfoLoader: WalletInfoLoader,
        tronUSDTFeesService: TronUsdtFeesService,
        multichainRealtimeManager: MultichainRealtimeManager,
        tonConnectEventsStore: TonConnectEventsStore,
        tonConnectObserver: TonConnectEventsStoreObserver
    ) {
        self.backgroundUpdate = backgroundUpdate
        self.walletsStore = walletsStore
        self.balanceLoader = balanceLoader
        self.walletInfoLoader = walletInfoLoader
        self.tronUSDTFeesService = tronUSDTFeesService
        self.multichainRealtimeManager = multichainRealtimeManager
        self.tonConnectEventsStore = tonConnectEventsStore
        self.tonConnectObserver = tonConnectObserver
    }

    func handle(_ command: MainControllerUpdatesCommand) {
        guard !isShutDown else { return }
        switch command {
        case .start:
            guard !updatesStarted else {
                // A brief resign does not stop updates, but a connection may still fail while the app
                // is inactive. Reconnect only failed sessions and leave healthy ones untouched.
                backgroundUpdate.reconnect()
                return
            }
            updatesStarted = true
            balanceLoader.setQuiet(false, owner: .appLifecycle)
            resumeConnections()
            guard let tonConnectObserver else { return }
            scheduleTonConnectTransition { store in
                await store.addObserver(tonConnectObserver)
                await store.start()
            }
        case .stop:
            guard updatesStarted else { return }
            performStop()
        case .reconnect:
            guard updatesStarted else { return }
            reconnectConnections()
        }
    }

    func shutdown() async {
        guard !isShutDown else { return }
        isShutDown = true
        if updatesStarted {
            performStop()
        }
        let transition = tonConnectTransition
        tonConnectTransition = nil
        await transition?.value
    }

    private func performStop() {
        updatesStarted = false
        balanceLoader.setQuiet(true, owner: .appLifecycle)
        balanceLoader.setRegularPollingPaused(false)
        backgroundUpdate.stop()
        tronUSDTFeesService.stop()
        multichainRealtimeManager.setForeground(false)
        let tonConnectObserver = tonConnectObserver
        scheduleTonConnectTransition { store in
            await store.stop()
            if let tonConnectObserver {
                await store.removeObserver(tonConnectObserver)
            }
        }
    }

    private func resumeConnections() {
        refreshData()
        backgroundUpdate.start()
        tronUSDTFeesService.start()
        multichainRealtimeManager.setForeground(true)
    }

    private func reconnectConnections() {
        refreshData()
        backgroundUpdate.reconnect()
        tronUSDTFeesService.start()
    }

    private func refreshData() {
        if let activeWallet = try? walletsStore.activeWallet {
            // The screen showing this wallet is about to ask for the same thing: at this priority
            // the two collapse into one run rather than queueing behind each other.
            Task { [balanceLoader] in
                await balanceLoader.reloadBalance(wallet: activeWallet, priority: .userVisible)
            }
        }
        walletInfoLoader.loadActiveWalletInfoNotifications()
    }

    /// TonConnect transitions await the previous one instead of cancelling it: a cancelled `stop()`
    /// would leave the store running.
    private func scheduleTonConnectTransition(
        _ transition: @escaping (TonConnectEventsStore) async -> Void
    ) {
        let previous = tonConnectTransition
        let store = tonConnectEventsStore
        tonConnectTransition = Task {
            await previous?.value
            await transition(store)
        }
    }
}
