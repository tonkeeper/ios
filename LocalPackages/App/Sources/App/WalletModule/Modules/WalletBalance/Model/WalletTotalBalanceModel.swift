import Foundation
import KeeperCore
import TKCore
import TonSwift

final class WalletTotalBalanceModel: @unchecked Sendable {
    struct State {
        let address: FriendlyAddress
        let totalBalanceState: TotalBalanceState?
        let isSecure: Bool
        let backgroundUpdateConnectionState: BackgroundUpdateConnectionState
        let isLoadingBalance: Bool
    }

    var didUpdateState: ((State) -> Void)?

    let wallet: Wallet

    private let totalBalanceStore: TotalBalanceStore
    private let appSettingsStore: AppSettingsStore
    private let backgroundUpdate: BackgroundUpdate
    private let updateQueue: DispatchQueue

    private let loadingLock = NSLock()
    private var isLoadingBalance = false

    private var backgroundStateTask: Task<Void, Never>?

    init(
        wallet: Wallet,
        totalBalanceStore: TotalBalanceStore,
        appSettingsStore: AppSettingsStore,
        backgroundUpdate: BackgroundUpdate,
        balanceLoader: BalanceLoader,
        updateQueue: DispatchQueue
    ) {
        self.wallet = wallet
        self.totalBalanceStore = totalBalanceStore
        self.appSettingsStore = appSettingsStore
        self.backgroundUpdate = backgroundUpdate
        self.updateQueue = updateQueue

        totalBalanceStore.addObserver(self) { observer, event in
            observer.didGetTotalBalanceStoreEvent(event)
        }

        appSettingsStore.addObserver(self) { observer, _ in
            observer.updateQueue.async { [weak observer] in
                observer?.updateModel()
            }
        }

        balanceLoader.addUpdateObserver(self) { observer, update in
            observer.setLoading(update.isLoading, for: update.wallet)
            observer.didGetWalletScopedEvent(update.wallet)
        }

        backgroundStateTask = Task { [weak self, walletID = wallet.id] in
            for await update in backgroundUpdate.stateUpdates() {
                guard update.walletID == walletID else { continue }
                guard let self else { return }
                didGetWalletScopedEvent(wallet)
            }
        }
    }

    deinit {
        backgroundStateTask?.cancel()
    }

    func getState() throws -> State {
        try State(
            address: wallet.friendlyAddress,
            totalBalanceState: totalBalanceStore.state[wallet],
            isSecure: appSettingsStore.state.isSecureMode,
            backgroundUpdateConnectionState: backgroundUpdate.connectionState(walletID: wallet.id),
            isLoadingBalance: loadingLock.withLock { isLoadingBalance }
        )
    }

    private func setLoading(_ isLoading: Bool, for wallet: Wallet) {
        guard wallet == self.wallet else { return }
        loadingLock.withLock { isLoadingBalance = isLoading }
    }

    private func didGetTotalBalanceStoreEvent(_ event: TotalBalanceStore.Event) {
        switch event {
        case let .didUpdateTotalBalance(wallet):
            didGetWalletScopedEvent(wallet)
        }
    }

    private func didGetWalletScopedEvent(_ wallet: Wallet) {
        guard wallet == self.wallet else { return }
        updateQueue.async { [weak self] in
            self?.updateModel()
        }
    }

    private func updateModel() {
        guard let state = try? getState() else { return }
        didUpdateState?(state)
    }
}
