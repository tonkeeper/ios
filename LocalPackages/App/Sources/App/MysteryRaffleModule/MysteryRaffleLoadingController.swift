import Foundation
import KeeperCore
import TKCore

final class MysteryRaffleLoadingController {
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let appStateTracker: AppStateTracker
    private let reachabilityTracker: ReachabilityTracker
    private var refreshTask: Task<Void, Never>?
    private var raffleImportFlushTask: Task<Void, Never>?

    init(
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        appStateTracker: AppStateTracker,
        reachabilityTracker: ReachabilityTracker
    ) {
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.appStateTracker = appStateTracker
        self.reachabilityTracker = reachabilityTracker
    }

    func start() {
        loadForActiveWallet()

        keeperCoreMainAssembly.storesAssembly.walletsStore.addObserver(self) { observer, event in
            switch event {
            case .didAddWallets,
                 .didChangeActiveWallet,
                 .didDeleteWallet,
                 .didDeleteAll,
                 .didUpdateWalletMultichain:
                Task { @MainActor in observer.loadForActiveWallet() }
            default:
                break
            }
        }

        keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate.addEventObserver(self) { observer, wallet, _ in
            Task { @MainActor in
                guard (try? observer.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet) == wallet else { return }
                observer.scheduleRefresh()
            }
        }

        appStateTracker.addObserver(self)
        reachabilityTracker.addObserver(self)
    }

    private func loadForActiveWallet() {
        guard
            let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
            case let .multichain(multichainState) = wallet.multichain
        else {
            keeperCoreMainAssembly.loadersAssembly.raffleLoader.clearRaffles()
            return
        }

        // The import task's report may not have reached the backend on the import itself. This
        // path already runs on foreground, reachability and wallet changes, so it doubles as the
        // retry for it. Cancel-and-replace: the reporter's actor lets these interleave, and two
        // passes over the same record would send the request twice and spend two of its retries.
        raffleImportFlushTask?.cancel()
        let raffleImportReporter = keeperCoreMainAssembly.multichainAssembly.raffleImportReporter
        raffleImportFlushTask = Task { await raffleImportReporter.flush() }

        keeperCoreMainAssembly.loadersAssembly.raffleLoader.loadRaffles(
            walletId: multichainState.walletId,
            lang: Locale.current.languageCode ?? "en",
            ids: nil
        )
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            let delay = TimeInterval.random(in: 2 ... 8)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.loadForActiveWallet()
        }
    }
}

extension MysteryRaffleLoadingController: AppStateTrackerObserver {
    func didUpdateState(_ state: TKCore.AppStateTracker.State) {
        switch (appStateTracker.state, reachabilityTracker.state) {
        case (.active, .connected):
            loadForActiveWallet()
        default:
            return
        }
    }
}

extension MysteryRaffleLoadingController: ReachabilityTrackerObserver {
    func didUpdateState(_ state: TKCore.ReachabilityTracker.State) {
        switch (appStateTracker.state, reachabilityTracker.state) {
        case (.active, .connected):
            loadForActiveWallet()
        default:
            return
        }
    }
}
