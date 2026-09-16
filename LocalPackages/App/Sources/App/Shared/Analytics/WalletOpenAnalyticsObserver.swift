import Foundation
import KeeperCore
import TKCore

final class WalletOpenAnalyticsObserver {
    private let walletsStore: WalletsStore
    private let analyticsProvider: AnalyticsProvider
    private var lastWalletOpenWalletId: String?

    init(
        walletsStore: WalletsStore,
        analyticsProvider: AnalyticsProvider
    ) {
        self.walletsStore = walletsStore
        self.analyticsProvider = analyticsProvider

        walletsStore.addObserver(self) { observer, event in
            observer.handle(event)
        }
    }

    @MainActor
    func start() {
        logCurrentWalletOpen()
    }

    private func handle(_ event: WalletsStore.Event) {
        guard case let .didChangeActiveWallet(_, to) = event else {
            return
        }

        Task { @MainActor in
            logWalletOpen(to)
        }
    }

    @MainActor
    private func logCurrentWalletOpen() {
        guard let wallet = try? walletsStore.activeWallet else {
            return
        }
        logWalletOpen(wallet)
    }

    @MainActor
    private func logWalletOpen(_ wallet: Wallet) {
        guard lastWalletOpenWalletId != wallet.id else {
            return
        }
        lastWalletOpenWalletId = wallet.id
        analyticsProvider.log(WalletOpen(wallet: wallet))
    }
}
