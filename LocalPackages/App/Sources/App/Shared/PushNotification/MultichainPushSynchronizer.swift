import Foundation
import TKLogging

/// What the last confirmed sync sent. `walletIds == nil` means this install never synced, so there
/// is no subscription to drop.
struct MultichainPushSyncState: Equatable {
    var walletIds: [String]?
    var token: String?
    var deviceId: String?
}

struct MultichainPushSynchronizerDependencies {
    var desiredWalletIds: () -> [String]
    var loadState: () -> MultichainPushSyncState
    var saveState: (MultichainPushSyncState) -> Void
    var deviceId: () async throws -> String
    var resolveToken: (_ hint: String?) async -> String?
    var requestAuthorization: () async -> Void
    var subscribe: (_ pushToken: String, _ walletIds: [String]) async throws -> Void
    var unsubscribe: () async throws -> Void
}

/// Push v2 is device-scoped: `wallet_ids` is the full set the user wants notified, so any change
/// replays the whole set instead of a per-wallet delta. Syncs are serialized rather than
/// cancel-and-replace, because a cancelled request can still land on the backend. Every successful
/// request records the backend state before the next serialized sync decides whether it has work.
final class MultichainPushSynchronizer {
    /// `settled` also covers a pass with nothing to do and one superseded by a newer schedule:
    /// in both cases the desired set is — or is about to be — what the backend holds. `deferred`
    /// is kept apart from `failed` because it already has a trigger that will retry it, so it must
    /// not be shown to the user as a rejected toggle.
    enum Outcome {
        case settled
        case deferred
        case failed
    }

    private let dependencies: MultichainPushSynchronizerDependencies
    private let queue = DispatchQueue(label: "MultichainPushSynchronizerQueue", qos: .userInitiated)
    private var generation = 0
    private var pending: Task<Outcome, Never>?

    init(dependencies: MultichainPushSynchronizerDependencies) {
        self.dependencies = dependencies
    }

    @discardableResult
    func schedule(token: String? = nil, requireAuthorization: Bool) -> Task<Outcome, Never>? {
        return queue.sync {
            generation += 1
            let generation = generation
            let previous = pending
            let task = Task { [weak self] () -> Outcome in
                _ = await previous?.value
                guard let self else { return .settled }
                return await self.sync(
                    token: token,
                    requireAuthorization: requireAuthorization,
                    generation: generation
                )
            }
            pending = task
            return task
        }
    }

    /// Awaits the tail of the chain rather than one caller's own pass. A superseded pass reports
    /// `settled` because the newer one carries its change, so only the pass that actually ran last
    /// can say whether the desired set reached the backend — every pass re-reads that set when it
    /// starts.
    func settledOutcome() async -> Outcome {
        var outcome = Outcome.settled
        while true {
            let (task, scheduled) = queue.sync { (pending, generation) }
            guard let task else { return outcome }
            outcome = await task.value
            guard !Task.isCancelled, queue.sync(execute: { generation }) != scheduled else {
                return outcome
            }
        }
    }
}

private extension MultichainPushSynchronizer {
    func isCurrent(_ generation: Int) -> Bool {
        queue.sync { generation == self.generation }
    }

    func sync(token: String?, requireAuthorization: Bool, generation: Int) async -> Outcome {
        if requireAuthorization {
            await dependencies.requestAuthorization()
        }
        guard isCurrent(generation) else { return .settled }

        let synced = dependencies.loadState()
        let walletIds = dependencies.desiredWalletIds()
        // An empty set with nothing ever synced means there is no subscription to drop,
        // so the device must not authenticate just to say so.
        guard !(walletIds.isEmpty && synced.walletIds == nil) else { return .settled }

        let deviceId: String
        do {
            deviceId = try await dependencies.deviceId()
        } catch {
            Log.w("🪵 Push: multichain sync failed — no device session", error: error)
            return .failed
        }
        guard isCurrent(generation) else { return .settled }
        // The subscription lives on the device id, so a rotated device has to be re-subscribed
        // even when the token and the wallet set are unchanged.
        let isSameScope = synced.deviceId == deviceId && synced.walletIds == walletIds

        // Dropping the whole set needs no push token — `/push/unsubscribe` authenticates with the
        // device JWT alone — so an unresolvable token must not leave the old subscription behind.
        if walletIds.isEmpty {
            guard !isSameScope else { return .settled }
            do {
                try await dependencies.unsubscribe()
            } catch {
                Log.w("🪵 Push: multichain unsubscribe failed", error: error)
                invalidateConfirmedScope(synced)
                return .failed
            }
            persist(MultichainPushSyncState(walletIds: [], token: nil, deviceId: deviceId))
            return .settled
        }

        guard let token = await dependencies.resolveToken(token) else {
            // The token's own arrival reconciles the subscriptions, so this is a wait, not a loss.
            Log.w("🪵 Push: multichain sync deferred — FCM token unavailable")
            return .deferred
        }
        guard isCurrent(generation) else { return .settled }
        guard !(isSameScope && synced.token == token) else { return .settled }

        do {
            try await dependencies.subscribe(token, walletIds)
        } catch {
            Log.w("🪵 Push: multichain sync failed", error: error)
            invalidateConfirmedScope(synced)
            return .failed
        }
        persist(MultichainPushSyncState(walletIds: walletIds, token: token, deviceId: deviceId))
        return .settled
    }

    /// A request that failed after it left the device may still have been applied, so the recorded
    /// scope is no longer something the backend confirmed. Dropping the token and the device id —
    /// rather than the wallet set, which is still the best guess at what is subscribed — makes the
    /// next pass send unconditionally instead of short-circuiting on an unchanged scope.
    ///
    /// `nil` wallet ids become `[]` for the same reason: `nil` claims this install has no
    /// subscription to drop, and after a failed first subscribe that claim is exactly what cannot
    /// be trusted — it would silence the compensating unsubscribe.
    func invalidateConfirmedScope(_ synced: MultichainPushSyncState) {
        let invalidated = MultichainPushSyncState(
            walletIds: synced.walletIds ?? [],
            token: nil,
            deviceId: nil
        )
        guard invalidated != synced else { return }
        persist(invalidated)
    }

    func persist(_ state: MultichainPushSyncState) {
        queue.sync {
            dependencies.saveState(state)
        }
    }
}
