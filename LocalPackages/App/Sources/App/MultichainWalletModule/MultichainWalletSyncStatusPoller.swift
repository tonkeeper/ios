import Foundation
import KeeperCore

@MainActor
final class MultichainWalletSyncStatusPoller {
    var onSyncStatusUpdate: (() async -> Void)?

    private let multichainService: MultichainService
    private let defaults: UserDefaults
    private var wallet: Wallet

    private var pollingTask: Task<Void, Never>?
    private var statusTracker = MultichainWalletSyncStatusPolling.Tracker()

    init(
        wallet: Wallet,
        multichainService: MultichainService,
        defaults: UserDefaults = .standard
    ) {
        self.wallet = wallet
        self.multichainService = multichainService
        self.defaults = defaults
    }

    deinit {
        pollingTask?.cancel()
    }

    func adopt(wallet: Wallet) {
        guard self.wallet == wallet else { return }
        self.wallet = wallet
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        statusTracker.reset()
    }

    func restart() {
        pollingTask?.cancel()
        guard case let .multichain(state) = wallet.multichain else {
            pollingTask = nil
            statusTracker.reset()
            return
        }
        let walletId = state.walletId
        let progressKey = Constants.progressKeyPrefix + walletId
        statusTracker.restart(walletIdentifier: walletId, persistedProgress: defaults.string(forKey: progressKey))

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                do {
                    let status = try await self.multichainService.getWalletSyncStatus(walletId: walletId)
                    guard !Task.isCancelled else { return }
                    if self.statusTracker.shouldNotify(current: status) {
                        self.defaults.set(self.statusTracker.observedProgress, forKey: progressKey)
                        await self.onSyncStatusUpdate?()
                    }
                    if !status.requiresPolling {
                        return
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                }

                try? await Task.sleep(nanoseconds: Constants.pollIntervalNanoseconds)
            }
        }
    }
}

enum MultichainWalletSyncStatusPolling {
    /// The asset load before the first status already shows any progress made before it, so the
    /// first status is compared with the last one seen, kept across launches, not taken as news.
    struct Tracker {
        private var walletIdentifier: String?
        private(set) var observedProgress: String?

        mutating func restart(walletIdentifier: String, persistedProgress: String? = nil) {
            guard self.walletIdentifier != walletIdentifier else { return }
            self.walletIdentifier = walletIdentifier
            observedProgress = persistedProgress
        }

        mutating func reset() {
            walletIdentifier = nil
            observedProgress = nil
        }

        mutating func shouldNotify(current: MultichainWalletSyncStatus) -> Bool {
            let currentProgress = current.chains
                .map { "\($0.key.rawValue):\($0.value.status.rawValue):\($0.value.backfill.rawValue)" }
                .sorted()
                .joined(separator: ",")
            defer { observedProgress = currentProgress }
            return observedProgress != currentProgress
        }
    }
}

private extension MultichainWalletSyncStatusPoller {
    enum Constants {
        static let pollIntervalNanoseconds: UInt64 = 2_000_000_000
        static let progressKeyPrefix = "multichainWalletSyncProgress."
    }
}
