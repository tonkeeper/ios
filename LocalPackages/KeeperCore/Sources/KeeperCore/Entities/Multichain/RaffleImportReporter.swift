import Foundation
import TKLogging

/// The raffle's "import a wallet" task pays the wallet the user started it from, not the wallet
/// they imported, so the source wallet id has to outlive the import flow — which switches the
/// active wallet and can span a relaunch. Held from the moment a task routes to wallet import
/// until the backend has the pair.
///
/// The imported wallet is kept by its local id and resolved to its multichain id at delivery time:
/// registration is what the endpoint asserts, and it can land after the import returns — or only on
/// a later pass, when the sync that failed during the import finally succeeds.
///
/// Records are kept per source wallet: each wallet runs the task on its own, so a pair that is
/// still undelivered must survive another wallet starting the same task.
public actor RaffleImportReporter {
    private struct Pending: Codable {
        var importedWalletIds: [String]
        /// Only drives the TTL. Ordering and identity go through `revision`, which no clock
        /// resolution can collapse.
        var updatedAt: Date
        /// Bumped from `Storage.nextRevision` on every change, so it both orders the records by
        /// when they were last started and lets a late delivery tell whether the record it sent is
        /// still the one stored.
        var revision: Int
        /// Passes the backend answered with a status of its own. Counted across flushes, and
        /// deliberately not bumping `revision`: a failed pass is not a newer record.
        var rejections = 0
    }

    private struct Storage: Codable {
        var pendings = [String: Pending]()
        var nextRevision = 0

        mutating func touch(_ sourceWalletId: String, now: Date, _ mutation: (inout Pending) -> Void) {
            var pending = pendings[sourceWalletId] ?? Pending(importedWalletIds: [], updatedAt: now, revision: 0)
            mutation(&pending)
            pending.updatedAt = now
            pending.revision = nextRevision
            pending.rejections = 0
            nextRevision += 1
            pendings[sourceWalletId] = pending
        }
    }

    typealias MarkImport = (_ walletId: String, _ importedWalletId: String) async throws(MultichainServiceError) -> Void
    /// The wallet's registered multichain id, or `nil` while the device is not bound to it.
    typealias ResolveRegisteredWalletId = (_ walletId: String) -> String?

    /// A tap the user never followed through on, and an import that never registers, are dropped
    /// rather than retried for the whole raffle.
    private static let ttl: TimeInterval = 7 * 24 * 60 * 60
    /// A rejected pair gets a few passes and is then dropped, so a permanent 400/403/404 does not
    /// spend the whole TTL sending a request the backend answers identically. The service layer
    /// collapses every status into `apiError`, so a recoverable 500 has to share the budget.
    private static let maxRejections = 5
    private static let storageKey = "raffle.pendingImport"

    private let userDefaults: UserDefaults
    private let resolveRegisteredWalletId: ResolveRegisteredWalletId
    private let markImport: MarkImport
    private let now: () -> Date
    private let sleep: MultichainRetry.Sleep

    init(
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping MultichainRetry.Sleep = MultichainRetry.defaultSleep,
        resolveRegisteredWalletId: @escaping ResolveRegisteredWalletId,
        markImport: @escaping MarkImport
    ) {
        self.userDefaults = userDefaults
        self.resolveRegisteredWalletId = resolveRegisteredWalletId
        self.markImport = markImport
        self.now = now
        self.sleep = sleep
    }

    /// Called when a raffle task routes the user to wallet import. Restarting the task keeps what
    /// the wallet already has undelivered — the user may just be reopening the import screen.
    public func beginImport(sourceWalletId: String) {
        var storage = load()
        storage.touch(sourceWalletId, now: now()) { _ in }
        save(storage)
    }

    /// Called with the local ids an import produced. They belong to the task the user started last:
    /// that is the flow that led here, and each source wallet's task pays once.
    func recordImported(walletIds: [String]) async {
        guard !walletIds.isEmpty else { return }
        var storage = load()
        guard
            let sourceWalletId = storage.pendings
            .max(by: { $0.value.revision < $1.value.revision })?
            .key
        else { return }
        storage.touch(sourceWalletId, now: now()) { $0.importedWalletIds = walletIds }
        save(storage)
        await flush()
    }

    /// Delivers every pair that is ready, and retries the ones an earlier pass could not resolve
    /// or send.
    public func flush() async {
        for (sourceWalletId, pending) in load().pendings {
            guard !Task.isCancelled else { return }
            await deliver(sourceWalletId: sourceWalletId, pending: pending)
        }
    }

    private func deliver(sourceWalletId: String, pending: Pending) async {
        guard
            let importedWalletId = pending.importedWalletIds
            .lazy
            .compactMap(resolveRegisteredWalletId)
            .first(where: { $0 != sourceWalletId })
        else { return }

        do {
            try await MultichainRetry.run(sleep: sleep) { () async throws(MultichainServiceError) in
                try await self.markImport(sourceWalletId, importedWalletId)
            }
        } catch .cancelled, .connectionError {
            // Nothing the backend saw, so the pass costs the record nothing.
            Log.w("🪵 Raffle: could not reach the backend to report the imported wallet")
            return
        } catch {
            Log.w("🪵 Raffle: the backend rejected the imported wallet report", error: error)
            rejectDelivery(sourceWalletId: sourceWalletId, revision: pending.revision)
            return
        }
        // The actor is reentrant across the request above, so the wallet may have started a new
        // import meanwhile. Only the record that was actually delivered is dropped.
        var storage = load()
        guard storage.pendings[sourceWalletId]?.revision == pending.revision else { return }
        storage.pendings[sourceWalletId] = nil
        save(storage)
    }

    /// Spends one of the record's passes. Guarded on the revision for the same reason the success
    /// path is: a newer record must not inherit an older pass's rejection.
    private func rejectDelivery(sourceWalletId: String, revision: Int) {
        var storage = load()
        guard var pending = storage.pendings[sourceWalletId], pending.revision == revision else { return }
        pending.rejections += 1
        storage.pendings[sourceWalletId] = pending.rejections < Self.maxRejections ? pending : nil
        save(storage)
    }

    private func load() -> Storage {
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return Storage() }
        guard var storage = try? JSONDecoder().decode(Storage.self, from: data) else {
            clear()
            return Storage()
        }
        let fresh = storage.pendings.filter { now().timeIntervalSince($0.value.updatedAt) < Self.ttl }
        guard fresh.count != storage.pendings.count else { return storage }
        storage.pendings = fresh
        save(storage)
        return storage
    }

    /// An emptied store is written rather than removed: dropping it would restart `nextRevision`,
    /// and a delivery still in flight could then match a record it never sent.
    private func save(_ storage: Storage) {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }

    private func clear() {
        userDefaults.removeObject(forKey: Self.storageKey)
    }
}
