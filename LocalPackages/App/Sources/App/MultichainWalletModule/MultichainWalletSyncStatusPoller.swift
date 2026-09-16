import Foundation
import KeeperCore

@MainActor
final class MultichainWalletSyncStatusPoller {
    var onSyncStatusUpdate: (() async -> Void)?

    private let walletsStore: WalletsStore
    private let multichainService: MultichainService

    private var pollingTask: Task<Void, Never>?
    private var statusTracker = MultichainWalletSyncStatusPolling.Tracker()

    init(
        walletsStore: WalletsStore,
        multichainService: MultichainService
    ) {
        self.walletsStore = walletsStore
        self.multichainService = multichainService
    }

    deinit {
        pollingTask?.cancel()
    }

    func restart(for wallet: Wallet?) {
        pollingTask?.cancel()
        guard let wallet,
              case let .multichain(state) = wallet.multichain
        else {
            pollingTask = nil
            statusTracker.reset()
            return
        }
        let walletId = state.walletId
        statusTracker.restart(walletIdentifier: walletId)

        pollingTask = Task { [weak self, walletIdentifier = wallet.id] in
            while !Task.isCancelled {
                guard let self, self.isActiveWallet(id: walletIdentifier) else { return }

                do {
                    let status = try await self.multichainService.getWalletSyncStatus(walletId: walletId)
                    guard !Task.isCancelled else { return }
                    if self.statusTracker.shouldNotify(current: status) {
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

    private func isActiveWallet(id: String) -> Bool {
        guard let activeWallet = try? walletsStore.activeWallet,
              case .multichain = activeWallet.multichain
        else {
            return false
        }
        return activeWallet.id == id
    }
}

enum MultichainWalletSyncStatusPolling {
    struct Tracker {
        private struct ChainProgress: Equatable {
            let status: MultichainChainSyncStatus.Status
            let backfill: MultichainChainSyncStatus.Backfill
        }

        private var walletIdentifier: String?
        private var previousProgress: [MultichainChain: ChainProgress]?

        mutating func restart(walletIdentifier: String) {
            guard self.walletIdentifier != walletIdentifier else { return }
            self.walletIdentifier = walletIdentifier
            previousProgress = nil
        }

        mutating func reset() {
            walletIdentifier = nil
            previousProgress = nil
        }

        mutating func shouldNotify(current: MultichainWalletSyncStatus) -> Bool {
            let currentProgress = current.chains.mapValues {
                ChainProgress(status: $0.status, backfill: $0.backfill)
            }
            guard let previousProgress else {
                self.previousProgress = currentProgress
                return true
            }
            self.previousProgress = currentProgress
            return previousProgress != currentProgress
        }
    }
}

private extension MultichainWalletSyncStatusPoller {
    enum Constants {
        static let pollIntervalNanoseconds: UInt64 = 2_000_000_000
    }
}
