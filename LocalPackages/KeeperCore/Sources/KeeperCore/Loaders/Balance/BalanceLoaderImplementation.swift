import Foundation
import TonSwift
import TronSwift

/// Orchestration only: who paces a request, who performs it, who is told about it and who is
/// waiting for the answer each live in their own type, so this one holds no state of its own.
final class BalanceLoaderImplementation: BalanceLoader {
    private enum Constants {
        static let idleReloadInterval: TimeInterval = 30
        static let fastReloadInterval: TimeInterval = 2
        static let hotWindowDuration: TimeInterval = 14
        /// Bounds event-driven refreshes outside a hot window. Small enough that an incoming
        /// transfer still feels live, large enough to collapse a batched transfer's landings.
        static let refreshThrottleInterval: TimeInterval = 5
        /// Someone is waiting on the screen for this one, so it is floored rather than paced: far
        /// enough below the automatic interval to feel immediate, still a floor a spammed
        /// pull-to-refresh cannot get under.
        static let waitedOnThrottleInterval: TimeInterval = 0.5
    }

    private let walletStore: WalletsStore
    private let currencyStore: CurrencyStore
    private let ratesStore: TonRatesStore
    private let ratesService: RatesService

    private let walletLoaders: WalletBalanceLoaderRegistry
    private let throttles: BalanceRefreshThrottleRegistry
    private let edges = BalanceLoadingEdges()
    private let balanceWaiters = BalanceRefreshWaiters()
    private let sweepWaiters = BalanceSweepWaiters()
    private let scheduler: BalanceReloadScheduler
    private let totalBalanceLoader: TotalBalanceLoader

    private let isRealtimeSubscribedLock = NSLock()
    private var isRealtimeSubscribed: @Sendable (String) -> Bool = { _ in false }
    private var transactionSendToken: NSObjectProtocol?

    init(
        walletStore: WalletsStore,
        currencyStore: CurrencyStore,
        ratesStore: TonRatesStore,
        ratesService: RatesService,
        walletStateLoaderProvider: @escaping (Wallet) -> WalletBalanceLoader,
        makeTotalBalanceLoader: (@escaping (Wallet, Currency, Bool) async -> Void) -> TotalBalanceLoader,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping BalanceRefreshThrottle.Sleep = BalanceRefreshThrottle.defaultSleep
    ) {
        self.walletStore = walletStore
        self.currencyStore = currencyStore
        self.ratesStore = ratesStore
        self.ratesService = ratesService

        let scheduler = BalanceReloadScheduler(
            hotInterval: Constants.fastReloadInterval,
            regularInterval: Constants.idleReloadInterval,
            hotDuration: Constants.hotWindowDuration,
            now: now,
            sleep: sleep
        )
        self.scheduler = scheduler
        walletLoaders = WalletBalanceLoaderRegistry(
            wallets: walletStore.wallets,
            makeLoader: walletStateLoaderProvider
        )

        weak var loader: BalanceLoaderImplementation?
        let minInterval: @Sendable (BalanceRefreshPriority) -> TimeInterval = { priority in
            Self.refreshInterval(priority: priority, mode: scheduler.mode)
        }
        throttles = BalanceRefreshThrottleRegistry(
            makeWalletThrottle: { wallet in
                let throttle = BalanceRefreshThrottle(
                    minInterval: minInterval,
                    now: now,
                    sleep: sleep,
                    operation: { run in
                        await loader?.reloadWalletBalance(wallet: wallet, run: run)
                    }
                )
                throttle.onIdle = { loader?.startRunForUnansweredWait(wallet: wallet) }
                return throttle
            },
            makeAllWalletsThrottle: {
                let throttle = BalanceRefreshThrottle(
                    minInterval: minInterval,
                    now: now,
                    sleep: sleep,
                    operation: { _ in
                        await loader?.reloadAllWalletsBalance()
                        loader?.sweepWaiters.resumeAll()
                    }
                )
                throttle.onIdle = { loader?.startSweepForUnansweredWait() }
                return throttle
            }
        )

        totalBalanceLoader = makeTotalBalanceLoader { wallet, currency, includingTransferFees in
            await loader?.loadWalletBalance(
                wallet: wallet,
                currency: currency,
                includingTransferFees: includingTransferFees
            )
        }

        // The collaborators above are built before `self` is whole, so the back-reference they hold
        // is handed over once it is — weakly, since they are owned from here.
        loader = self
        transactionSendToken = NotificationCenter.default.addObserver(
            forName: .transactionSendNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleTransactionSend(notification)
        }
        scheduler.onTick = { [weak self] in
            self?.requestActiveWalletReload(priority: .background)
        }
        setupObservations()
    }

    deinit {
        if let transactionSendToken {
            NotificationCenter.default.removeObserver(transactionSendToken)
        }
        scheduler.cancel()
        throttles.cancelAll()
        balanceWaiters.settleAll(result: .dropped)
        sweepWaiters.resumeAll()
    }

    func reloadBalance(
        wallet: Wallet,
        priority: BalanceRefreshPriority
    ) async -> BalanceRefreshResult {
        guard scheduler.admits(priority) else { return .dropped }
        let waiters = balanceWaiters
        let id = waiters.reserve()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Before the request, so a run cannot complete between the two.
                guard waiters.register(id, wallet: wallet, continuation: continuation) else {
                    return continuation.resume(returning: .dropped)
                }
                let throttle = throttles.throttle(for: wallet)
                throttle.request(priority: priority)
                // A request that rides the run in flight is answered when that run settles. If it
                // had already settled as this one was deciding, there is nothing left to answer
                // this wait, so it asks again.
                guard throttle.isIdle, waiters.isWaiting(id) else { return }
                throttle.request(priority: priority)
            }
        } onCancel: {
            waiters.retire(id)
        }
    }

    func reloadAllWalletsBalance(priority: BalanceRefreshPriority) async {
        guard scheduler.admits(priority) else { return }
        let waiters = sweepWaiters
        let id = waiters.reserve()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard waiters.register(id, continuation: continuation) else {
                    return continuation.resume()
                }
                throttles.allWalletsThrottle().request(priority: priority)
            }
        } onCancel: {
            waiters.retire(id)
        }
    }

    /// Entering quiet also drops what is already in flight — handing the request budget over is the
    /// whole point of asking, and a reload that keeps running would spend it anyway.
    func setQuiet(_ isQuiet: Bool, owner: BalanceQuietOwner) {
        scheduler.setQuiet(isQuiet, owner: owner)
        guard isQuiet else { return }
        // Cancelling the throttles reaches the runs themselves: every load is awaited by the run
        // that started it, so cancelling that run cancels the load it is waiting on.
        throttles.cancelAll()
        balanceWaiters.settleAll(result: .dropped)
        sweepWaiters.resumeAll()
    }

    func setRegularPollingPaused(_ paused: Bool) {
        scheduler.setRegularPollingPaused(paused)
    }

    func setIsRealtimeSubscribed(_ isSubscribed: @escaping @Sendable (String) -> Bool) {
        isRealtimeSubscribedLock.lock()
        isRealtimeSubscribed = isSubscribed
        isRealtimeSubscribedLock.unlock()
    }

    func addUpdateObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, BalanceLoaderUpdate) -> Void
    ) {
        edges.addObserver(observer, closure: closure)
    }

    private func handleTransactionSend(_ notification: Notification) {
        let wallet = (notification.userInfo?["wallet"] as? Wallet)
            ?? (try? walletStore.activeWallet)
        guard let wallet else { return }

        guard scheduler.admits(.background) else { return }
        throttles.throttle(for: wallet).request(priority: .background)

        if let walletId = wallet.multichainWalletState?.walletId, isSubscribedToRealtime(walletId: walletId) {
            return
        }
        scheduler.enterHotWindow()
    }

    private func isSubscribedToRealtime(walletId: String) -> Bool {
        isRealtimeSubscribedLock.lock()
        let check = isRealtimeSubscribed
        isRealtimeSubscribedLock.unlock()
        return check(walletId)
    }

    /// The loader's own cadence: the tick, the window a transfer opens and the wallet the app just
    /// switched to. Nobody is awaiting these, so they only need to reach the throttle.
    private func requestActiveWalletReload(priority: BalanceRefreshPriority) {
        guard scheduler.admits(priority), let wallet = try? walletStore.activeWallet else { return }
        throttles.throttle(for: wallet).request(priority: priority)
    }

    /// Inside a hot window the tick and the event-driven refreshes share the fast interval, so both
    /// are paced by the same gate. A request someone is waiting on is not paced with them.
    private static func refreshInterval(
        priority: BalanceRefreshPriority,
        mode: BalanceLoaderMode
    ) -> TimeInterval {
        switch priority {
        case .userInitiated, .userVisible:
            Constants.waitedOnThrottleInterval
        case .background:
            switch mode {
            case .hot: Constants.fastReloadInterval
            case .regular, .quiet: Constants.refreshThrottleInterval
            }
        }
    }

    private func reloadWalletBalance(wallet: Wallet, run: Int) async {
        let currency = currencyStore.state
        await loadRates(currency: currency)
        guard !Task.isCancelled, let loader = walletLoaders.loader(for: wallet) else {
            return settle(wallet, run: run, result: .dropped)
        }
        edges.begin(wallet: wallet)
        let result = await loader.reloadBalance(currency: currency)
        edges.end(wallet: wallet, result: result)
        settle(wallet, run: run, result: result)
    }

    /// A request rides the run in flight instead of queueing one of its own, and it can register
    /// its wait in the moment between that run settling and the throttle noticing it is over. The
    /// run it rode is gone by then, so the throttle falling idle with a wait still on the books is
    /// where the run that answers it is started.
    private func startRunForUnansweredWait(wallet: Wallet) {
        guard balanceWaiters.hasWaiters(for: wallet) else { return }
        throttles.existingThrottle(for: wallet)?.request(priority: .userVisible)
    }

    private func startSweepForUnansweredWait() {
        guard sweepWaiters.hasWaiters else { return }
        throttles.allWalletsThrottle().request(priority: .userVisible)
    }

    /// A cancelled run still reaches its completion, by which time the wait it carried has been
    /// answered by the cancellation and the one in the registry belongs to a later run.
    private func settle(_ wallet: Wallet, run: Int, result: BalanceRefreshResult) {
        guard throttles.existingThrottle(for: wallet)?.isRunCurrent(run) == true else { return }
        balanceWaiters.settle(wallet, result: result)
    }

    private func reloadAllWalletsBalance() async {
        let currency = currencyStore.state
        await loadRates(currency: currency)
        guard !Task.isCancelled else { return }
        await totalBalanceLoader.reloadBalances(
            wallets: walletStore.wallets,
            activeWallet: try? walletStore.activeWallet,
            currency: currency
        )
    }

    /// Handed to the sweep as its legacy mechanic, so the loading edges it produces are published
    /// by the loader that owns the observers rather than by the one pacing the requests.
    private func loadWalletBalance(
        wallet: Wallet,
        currency: Currency,
        includingTransferFees: Bool
    ) async {
        guard let loader = walletLoaders.loader(for: wallet) else { return }
        edges.begin(wallet: wallet)
        let result = await loader.reloadBalance(
            currency: currency,
            includingTransferFees: includingTransferFees
        )
        edges.end(wallet: wallet, result: result)
    }

    private func setupObservations() {
        walletStore.addObserver(self) { observer, event in
            switch event {
            case let .didAddWallets(wallets):
                observer.walletLoaders.add(wallets: wallets)
            case let .didDeleteWallet(wallet):
                observer.walletLoaders.remove(wallet: wallet)
                observer.throttles.remove(wallet: wallet)?.cancel()
                observer.balanceWaiters.settle(wallet, result: .dropped)
            case .didChangeActiveWallet:
                // The screen following the selection asks for the same wallet as it appears, and a
                // switch is not a change being reported: both want the one run this starts.
                observer.requestActiveWalletReload(priority: .userVisible)
            default: break
            }
        }

        currencyStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateCurrency:
                observer.requestActiveWalletReload(priority: .userInitiated)
            }
        }
    }

    /// Publishing an empty state on failure would drop the fiat values the UI is already showing,
    /// so an unavailable response leaves the store as it is.
    private func loadRates(currency: Currency) async {
        do {
            let rates = try await ratesService.loadRates(
                jettons: [JettonMasterAddress.USDe.toRaw(), TRX.symbol],
                currencies: [currency, .GRAM, .USD]
            )
            try Task.checkCancellation()
            await ratesStore.setRates(ton: rates.ton, usdt: rates.usdt, jettonRates: rates.jettonRates)
        } catch {
            return
        }
    }
}
