import Foundation
import KeeperCoreSensitive
import TKLogging

public protocol MultichainWalletSyncController {
    var needsStartupSync: Bool { get }
    /// True when a synced wallet is missing its durable app key and needs a passcode-gated warm.
    func needsStartupAppKeyWarm() async -> Bool
    func syncPendingWallets(passcode: String) async
    /// Derives and persists missing app keys for already-synced wallets. No register/re-sync.
    func warmMissingAppKeys(passcode: String) async
    /// Silent, no-passcode pass over the device's bindings. Wallets the device is not bound to
    /// go back to `pending` for the next passcode-gated sync (re-signing needs the mnemonic);
    /// bindings for wallets that no longer exist locally are detached.
    ///
    /// Returns `false` when the pass did not get as far as the detach — the bindings could not be
    /// read, or a wallet awaiting enrichment leaves a stale binding indistinguishable from a live
    /// one — so a caller that owns a retry trigger can run it again; anything the pass did with the
    /// bindings is best effort.
    @discardableResult
    func reconcileBindings() async -> Bool
}

// MARK: -

struct MultichainWalletSyncControllerDependencies {
    var getWallets: () -> [Wallet]
    var getMnemonics: (_ wallets: [Wallet], _ passcode: String) async throws -> [CoreMnemonicIdentifier: CoreMnemonic]
    var syncWallet: (_ mnemonic: String, _ state: MultichainWalletState) async throws(MultichainServiceError) -> Void
    /// Only `walletId` and `syncState` are honoured. The addresses belong to the enricher, which
    /// writes them without waiting for a sync, so the store merges the two writers inside one
    /// update instead of letting either restore the other's previous value.
    var saveWallet: (_ wallet: Wallet, _ multichain: MultichainWallet) async -> Void
    var hasPersistentAppKey: (_ walletId: String) async -> Bool
    var warmAppKey: (_ walletId: String, _ mnemonic: String) async -> Void
    var getDeviceBindings: (_ walletIds: [String]) async throws(MultichainServiceError) -> DeviceBindings
    var unregisterWallets: (_ walletIds: [String]) async throws(MultichainServiceError) -> Void
    var isDeviceKnown: () async -> Bool
}

final class MultichainWalletSyncControllerImplementation {
    /// Both operations write wallet sync state, and a device rotation inside a sync triggers a
    /// reconcile, so they run one at a time: an interleaved reconcile could otherwise revert a
    /// wallet the sync had just registered.
    private actor Gate {
        private struct Waiter {
            let id: UUID
            let continuation: CheckedContinuation<Bool, Never>
        }

        private var isOccupied = false
        private var waiters = [Waiter]()
        private var registeringWaiterIds = Set<UUID>()
        private var cancelledWaiterIds = Set<UUID>()

        func acquire() async -> Bool {
            guard !Task.isCancelled else { return false }
            guard isOccupied else {
                isOccupied = true
                return true
            }

            let id = UUID()
            registeringWaiterIds.insert(id)
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    let wasCancelledBeforeRegistration = cancelledWaiterIds.remove(id) != nil
                    registeringWaiterIds.remove(id)
                    guard !Task.isCancelled, !wasCancelledBeforeRegistration else {
                        continuation.resume(returning: false)
                        return
                    }
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            } onCancel: {
                Task { await self.cancel(id: id) }
            }
        }

        func release() {
            guard !waiters.isEmpty else {
                isOccupied = false
                return
            }
            waiters.removeFirst().continuation.resume(returning: true)
        }

        private func cancel(id: UUID) {
            if let index = waiters.firstIndex(where: { $0.id == id }) {
                waiters.remove(at: index).continuation.resume(returning: false)
            } else if registeringWaiterIds.contains(id) {
                cancelledWaiterIds.insert(id)
            }
        }
    }

    private let dependencies: MultichainWalletSyncControllerDependencies
    private let sleep: MultichainRetry.Sleep
    private let gate = Gate()

    init(
        dependencies: MultichainWalletSyncControllerDependencies,
        sleep: @escaping MultichainRetry.Sleep = MultichainRetry.defaultSleep
    ) {
        self.dependencies = dependencies
        self.sleep = sleep
    }
}

extension MultichainWalletSyncControllerImplementation: MultichainWalletSyncController {
    var needsStartupSync: Bool {
        !walletsNeedingSync().isEmpty
    }

    func needsStartupAppKeyWarm() async -> Bool {
        !(await walletsNeedingAppKeyWarm()).isEmpty
    }

    func syncPendingWallets(passcode: String) async {
        guard await gate.acquire() else { return }
        guard !Task.isCancelled else {
            await gate.release()
            return
        }
        await performSyncPendingWallets(passcode: passcode)
        await gate.release()
    }

    func warmMissingAppKeys(passcode: String) async {
        guard await gate.acquire() else { return }
        guard !Task.isCancelled else {
            await gate.release()
            return
        }
        await performWarmMissingAppKeys(passcode: passcode)
        await gate.release()
    }

    @discardableResult
    func reconcileBindings() async -> Bool {
        guard await gate.acquire() else { return false }
        guard !Task.isCancelled else {
            await gate.release()
            return false
        }
        let didReconcile = await performReconcileBindings()
        await gate.release()
        return didReconcile
    }
}

private extension MultichainWalletSyncControllerImplementation {
    static let maxBindingsRequestSize = 200

    func performSyncPendingWallets(passcode: String) async {
        guard !Task.isCancelled else { return }
        let wallets = walletsNeedingSync()
        guard !wallets.isEmpty else {
            return
        }

        let mnemonicsByWalletId: [CoreMnemonicIdentifier: CoreMnemonic]
        do {
            mnemonicsByWalletId = try await dependencies.getMnemonics(wallets.map(\.wallet), passcode)
        } catch {
            guard !Task.isCancelled else { return }
            Log.w("failed to load mnemonics for multichain wallet sync", error: error)
            return
        }

        for (wallet, state) in wallets {
            guard !Task.isCancelled else { return }
            guard let mnemonic = mnemonicsByWalletId[wallet.id] else {
                Log.w(
                    "failed to sync multichain wallet due to missing mnemonic",
                    error: MultichainLoggingError.missingMnemonic(operation: "sync")
                )
                await save(wallet: wallet, state: state, syncState: .failed)
                continue
            }

            let phrase = mnemonic.mnemonicWords.joined(separator: " ")
            do {
                // A dropped connection here used to mark the wallet `.failed` until the next cold
                // start; the register sequence re-signs against a fresh challenge on every pass.
                try await MultichainRetry.run(sleep: sleep) { () async throws(MultichainServiceError) in
                    try await self.dependencies.syncWallet(phrase, state)
                }
                await save(wallet: wallet, state: state, syncState: .synced)
            } catch {
                guard !Task.isCancelled else { return }
                Log.w(
                    "failed to sync multichain wallet",
                    error: error
                )
                await save(wallet: wallet, state: state, syncState: .failed)
            }
        }
    }

    func performWarmMissingAppKeys(passcode: String) async {
        guard !Task.isCancelled else { return }
        let wallets = await walletsNeedingAppKeyWarm()
        guard !wallets.isEmpty else {
            return
        }

        let mnemonicsByWalletId: [CoreMnemonicIdentifier: CoreMnemonic]
        do {
            mnemonicsByWalletId = try await dependencies.getMnemonics(wallets.map(\.wallet), passcode)
        } catch {
            guard !Task.isCancelled else { return }
            Log.w("failed to load mnemonics for multichain app key warm", error: error)
            return
        }

        for (wallet, state) in wallets {
            guard !Task.isCancelled else { return }
            guard let mnemonic = mnemonicsByWalletId[wallet.id] else {
                Log.w(
                    "failed to warm multichain app key due to missing mnemonic",
                    error: MultichainLoggingError.missingMnemonic(operation: "warm")
                )
                continue
            }
            let phrase = mnemonic.mnemonicWords.joined(separator: " ")
            await dependencies.warmAppKey(state.walletId, phrase)
        }
    }

    func performReconcileBindings() async -> Bool {
        guard !Task.isCancelled else { return false }
        let wallets = multichainWallets()
        let localWalletIds = Array(Set(wallets.map(\.state.walletId)))
        // Snapshot: the local set the request is built from and the verdict on it have to describe
        // the same moment, or a wallet enriched mid-request would be judged against ids that were
        // never sent.
        let awaitsEnrichment = hasWalletAwaitingEnrichment()
        // With nothing to send, the only thing the pass could learn is a stale set it must not act
        // on. Reported as unfinished, so the next trigger runs it once the state is there.
        if localWalletIds.isEmpty, awaitsEnrichment {
            return false
        }
        // An empty list is a valid request and the only way to find bindings left by wallets that
        // are already gone — but only once the device exists, otherwise there is nothing to find.
        if localWalletIds.isEmpty, await !dependencies.isDeviceKnown() {
            return true
        }
        guard !Task.isCancelled else { return false }
        let isTruncated = localWalletIds.count > Self.maxBindingsRequestSize
        if isTruncated {
            Log.w("🪵 Multichain: bindings reconcile truncated to \(Self.maxBindingsRequestSize) of \(localWalletIds.count) wallets")
        }

        let bindings: DeviceBindings
        do {
            bindings = try await MultichainRetry.run(sleep: sleep) { () async throws(MultichainServiceError) in
                try await self.dependencies.getDeviceBindings(
                    Array(localWalletIds.prefix(Self.maxBindingsRequestSize))
                )
            }
        } catch {
            guard !Task.isCancelled else { return false }
            Log.w("🪵 Multichain: bindings reconcile failed", error: error)
            return false
        }

        guard !Task.isCancelled else { return false }

        let unknown = Set(bindings.unknown)
        for (wallet, state) in wallets where unknown.contains(state.walletId) && state.syncState == .synced {
            guard !Task.isCancelled else { return false }
            await save(wallet: wallet, state: state, syncState: .pending)
        }

        // A truncated request cannot tell a stale binding from one that simply was not sent.
        guard !isTruncated else {
            return true
        }
        // Same blind spot for a wallet awaiting enrichment: it has no id to send, so its binding is
        // indistinguishable from one left behind by a wallet that is gone. Demoting what the device
        // does not know is still safe, detaching is not.
        guard !awaitsEnrichment else {
            return false
        }
        let local = Set(localWalletIds)
        let stale = bindings.extra.filter { !local.contains($0) }
        guard !stale.isEmpty else {
            return true
        }
        guard !Task.isCancelled else { return false }
        do {
            try await dependencies.unregisterWallets(stale)
        } catch {
            guard !Task.isCancelled else { return true }
            Log.w("🪵 Multichain: failed to detach stale bindings", error: error)
        }
        return true
    }
}

private extension MultichainWalletSyncControllerImplementation {
    func walletsNeedingSync() -> [(wallet: Wallet, state: MultichainWalletState)] {
        multichainWallets().filter { $0.state.syncState != .synced }
    }

    func walletsNeedingAppKeyWarm() async -> [(wallet: Wallet, state: MultichainWalletState)] {
        var result = [(wallet: Wallet, state: MultichainWalletState)]()
        for entry in multichainWallets() where entry.state.syncState == .synced {
            if await dependencies.hasPersistentAppKey(entry.state.walletId) {
                continue
            }
            result.append(entry)
        }
        return result
    }

    func multichainWallets() -> [(wallet: Wallet, state: MultichainWalletState)] {
        dependencies.getWallets().compactMap { wallet in
            guard wallet.kind == .regular,
                  wallet.network == .mainnet,
                  case let .multichain(state) = wallet.multichain,
                  !state.addresses.isEmpty
            else {
                return nil
            }
            return (wallet, state)
        }
    }

    /// The mirror of what `multichainWallets()` drops for a reason enrichment can still fix: a
    /// wallet with no state yet, or one whose addresses have not been derived. `.unavailable` has
    /// been through enrichment already and never contributes a walletId.
    func hasWalletAwaitingEnrichment() -> Bool {
        dependencies.getWallets().contains { wallet in
            guard wallet.kind == .regular, wallet.network == .mainnet else {
                return false
            }
            switch wallet.multichain {
            case nil:
                return true
            case let .multichain(state):
                return state.addresses.isEmpty
            case .unavailable:
                return false
            }
        }
    }

    /// The re-read is an early-out, not the guarantee: a wallet that is gone — or no longer maps to
    /// the walletId the network call was about — is skipped before the write is even attempted,
    /// while the write itself re-reads and merges inside the store update.
    func save(
        wallet: Wallet,
        state: MultichainWalletState,
        syncState: MultichainWalletSyncState
    ) async {
        guard let current = currentState(of: wallet), current.walletId == state.walletId else {
            return
        }
        await dependencies.saveWallet(
            wallet,
            .multichain(
                MultichainWalletState(
                    walletId: current.walletId,
                    addresses: current.addresses,
                    syncState: syncState
                )
            )
        )
    }

    func currentState(of wallet: Wallet) -> MultichainWalletState? {
        guard let stored = dependencies.getWallets().first(where: { $0.id == wallet.id }),
              case let .multichain(state) = stored.multichain
        else {
            return nil
        }
        return state
    }
}
