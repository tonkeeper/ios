import Foundation
import KeeperCoreSensitive
import TKLogging

public actor LegacyBatteryMigrationController {
    struct Dependencies: Sendable {
        var load: @Sendable () throws -> LegacyBatteryMigrationStore.State
        var save: @Sendable (LegacyBatteryMigrationStore.State) throws -> Void
        // Encoded snapshots keep mutable wallet models inside the isolation domain that owns them.
        var wallets: @Sendable () async -> [Data]
        var balance: @Sendable (Data) async throws -> BatteryBalance
        var waitUntilIdle: @Sendable (Data) async throws -> Bool
        var migrate: @Sendable (Data, BatteryMigrationProof) async throws -> Void
        var refreshBalance: @Sendable (Data) async -> Void
        var authorizationAvailable: @Sendable (Data) -> Bool = { _ in true }
        var refreshAuthorization: @Sendable (_ wallet: Data, _ privateKey: Data) async throws -> Void = { _, _ in }
        var now: @Sendable () -> Date = { Date() }
        var offerCacheLifetime: TimeInterval = 10
    }

    private let dependencies: Dependencies
    private var state: LegacyBatteryMigrationStore.State?
    private var worker: Task<Void, Never>?
    private var hasPendingResume = false
    private struct AuthorizationWorker {
        let generation: UUID
        let walletId: String
        let task: Task<Void, Never>
    }

    private var authorizationWorkers = [String: AuthorizationWorker]()
    private struct MigrationWorker: Sendable {
        let generation: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<Void, Error>]
        var isCancelling = false
    }

    struct PaymentAuthorization: Sendable {
        let migration: LegacyBatteryMigration
        let privateKey: Data
    }

    private var migrationWorkers = [String: MigrationWorker]()
    private struct MigrationOffer {
        let value: Bool
        let expires: Date
    }

    private struct OfferWorker {
        let generation: UUID
        let task: Task<Bool, Never>
    }

    private var migrationOffers = [String: MigrationOffer]()
    private var offerWorkers = [String: OfferWorker]()

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    @discardableResult
    func prepare(mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]) async -> Task<Void, Never> {
        guard !Task.isCancelled else { return Task {} }
        let wallets = await dependencies.wallets()
        for data in wallets {
            do {
                let wallet = try JSONDecoder().decode(Wallet.self, from: data)
                guard let mnemonic = mnemonics[wallet.id] else { continue }
                try prepare(wallet: wallet, mnemonic: mnemonic)
            } catch {
                Log.migration.w("legacy battery proof preparation failed", error: error)
            }
        }
        return resume()
    }

    func prepare(wallet data: Data, mnemonic: CoreMnemonic) throws {
        try prepare(wallet: JSONDecoder().decode(Wallet.self, from: data), mnemonic: mnemonic)
    }

    func needsMigration(wallet data: Data) throws -> Bool {
        let wallet = try JSONDecoder().decode(Wallet.self, from: data)
        guard wallet.network == .mainnet, wallet.kind == .regular, !wallet.isWalletTg,
              let walletId = wallet.multichainWalletId
        else { return false }
        return try !load().completed.contains(LegacyBatteryMigration.identifier(wallet: wallet, walletId: walletId))
    }

    func offersMigration(wallet data: Data) async -> Bool {
        guard (try? needsMigration(wallet: data)) == true else { return false }
        guard let wallet = try? JSONDecoder().decode(Wallet.self, from: data), let walletId = wallet.multichainWalletId else { return false }
        let id = LegacyBatteryMigration.identifier(wallet: wallet, walletId: walletId)
        if migrationWorkers[id] != nil { return true }
        if let cached = migrationOffers[id], cached.expires > dependencies.now() { return cached.value }
        let worker: OfferWorker
        if let current = offerWorkers[id] {
            worker = current
        } else {
            worker = OfferWorker(generation: UUID(), task: Task {
                do {
                    let balance = try await self.dependencies.balance(data)
                    guard let amount = Self.decimal(balance.balance), let reserved = Self.decimal(balance.reserved) else { return false }
                    return amount.compare(NSDecimalNumber.zero) == .orderedDescending || reserved.compare(NSDecimalNumber.zero) == .orderedDescending
                } catch {
                    // The old TON proof can only be renewed after the user's ordinary unlock.
                    return Self.isAuthorizationError(error)
                }
            })
            offerWorkers[id] = worker
        }
        let offered = await worker.task.value
        guard (try? needsMigration(wallet: data)) == true else { return false }
        if offerWorkers[id]?.generation == worker.generation {
            offerWorkers.removeValue(forKey: id)
            migrationOffers[id] = MigrationOffer(value: offered, expires: dependencies.now().addingTimeInterval(dependencies.offerCacheLifetime))
            return Task.isCancelled ? false : offered
        }
        guard !Task.isCancelled else { return false }
        return await offersMigration(wallet: data)
    }

    func preparePayment(wallet data: Data, mnemonic: CoreMnemonic) throws -> PaymentAuthorization? {
        guard try needsMigration(wallet: data) else { return nil }
        let wallet = try JSONDecoder().decode(Wallet.self, from: data)
        guard mnemonic.type == .bip39 else { throw BatteryAuthorizationError.legacyProofUnavailable }
        try prepare(wallet: wallet, mnemonic: mnemonic)
        let keyPair = try mnemonic.toKeyPair()
        guard try keyPair.publicKey == wallet.publicKey,
              let walletId = wallet.multichainWalletId,
              let migration = try load().pending[LegacyBatteryMigration.identifier(wallet: wallet, walletId: walletId)]
        else { throw BatteryAuthorizationError.legacyProofUnavailable }
        return PaymentAuthorization(migration: migration, privateKey: keyPair.privateKey.data)
    }

    func ensureMigrated(_ authorization: PaymentAuthorization) async throws {
        let migration = authorization.migration
        for attempt in 0 ... 1 {
            try Task.checkCancellation()
            guard let current = await currentWallet(for: migration) else { throw MigrationError.walletUnavailable }
            if try load().completed.contains(migration.id) { return }
            if try load().pending[migration.id]?.requiresAuthorizationRefresh == true || !dependencies.authorizationAvailable(current) {
                try await refreshForPayment(authorization, wallet: current)
            }
            do {
                try await migrate(migration)
                try Task.checkCancellation()
                return
            } catch {
                guard attempt == 0, Self.isAuthorizationError(error) else { throw error }
                try await refreshForPayment(authorization, wallet: current)
            }
        }
    }

    private func refreshForPayment(_ authorization: PaymentAuthorization, wallet data: Data) async throws {
        let id = authorization.migration.id
        if let existing = authorizationWorkers[id] {
            await existing.task.value
            try Task.checkCancellation()
            if try load().completed.contains(id) || load().pending[id]?.requiresAuthorizationRefresh == false { return }
        }
        let wallet = try JSONDecoder().decode(Wallet.self, from: data)
        var updated = try load()
        if updated.completed.contains(id) { return }
        updated.pending[id]?.requiresAuthorizationRefresh = true
        try commit(updated)
        refreshAuthorization(id: id, wallet: data, walletId: wallet.id, privateKey: authorization.privateKey)
        await authorizationWorkers[id]?.task.value
        try Task.checkCancellation()
        guard try load().completed.contains(id) || load().pending[id]?.requiresAuthorizationRefresh == false else {
            throw BatteryAuthorizationError.legacyProofUnavailable
        }
    }

    func cancelAuthorization(walletId: String? = nil) {
        let ids = authorizationWorkers.filter { walletId == nil || $0.value.walletId == walletId }.map(\.key)
        for id in ids {
            authorizationWorkers.removeValue(forKey: id)?.task.cancel()
        }
    }

    @discardableResult
    public func resume() -> Task<Void, Never> {
        if let worker {
            hasPendingResume = true
            return worker
        }
        hasPendingResume = false
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runPending()
        }
        worker = task
        return task
    }

    private func prepare(wallet: Wallet, mnemonic: CoreMnemonic) throws {
        guard wallet.network == .mainnet, wallet.kind == .regular, !wallet.isWalletTg,
              mnemonic.type == .bip39, let walletId = wallet.multichainWalletId
        else { return }
        let id = LegacyBatteryMigration.identifier(wallet: wallet, walletId: walletId)
        var updated = try load()
        guard !updated.completed.contains(id) else { return }
        if updated.pending[id] == nil {
            guard let migration = try LegacyBatteryMigration(wallet: wallet, mnemonic: mnemonic) else { return }
            updated.pending[id] = migration
            try commit(updated)
            invalidateOffer(id)
        }
        let data = try JSONEncoder().encode(wallet)
        if updated.pending[id]?.requiresAuthorizationRefresh == true || !dependencies.authorizationAvailable(data) {
            guard authorizationWorkers[id] == nil else { return }
            let keyPair = try mnemonic.toKeyPair()
            guard try keyPair.publicKey == wallet.publicKey else { throw BatteryAuthorizationError.unavailable }
            updated.pending[id]?.requiresAuthorizationRefresh = true
            try commit(updated)
            refreshAuthorization(id: id, wallet: data, walletId: wallet.id, privateKey: keyPair.privateKey.data)
        }
    }

    private func refreshAuthorization(id: String, wallet: Data, walletId: String, privateKey: Data) {
        let refresh = dependencies.refreshAuthorization
        let generation = UUID()
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                try await refresh(wallet, privateKey)
                try Task.checkCancellation()
                await self?.authorizationFinished(id: id, generation: generation, succeeded: true)
            } catch {
                Log.migration.w("legacy battery authorization refresh deferred", error: error)
                await self?.authorizationFinished(id: id, generation: generation, succeeded: false)
            }
        }
        authorizationWorkers[id] = AuthorizationWorker(generation: generation, walletId: walletId, task: task)
    }

    private func authorizationFinished(id: String, generation: UUID, succeeded: Bool) {
        guard authorizationWorkers[id]?.generation == generation else { return }
        authorizationWorkers.removeValue(forKey: id)
        invalidateOffer(id)
        if succeeded {
            do {
                var updated = try load()
                updated.pending[id]?.requiresAuthorizationRefresh = false
                try commit(updated)
            } catch {
                Log.migration.w("legacy battery authorization refresh could not persist", error: error)
            }
        }
        resume()
    }

    private func runPending() async {
        defer {
            worker = nil
            hasPendingResume = false
        }
        var attempted = Set<String>()
        while !Task.isCancelled {
            let migration: LegacyBatteryMigration
            do {
                guard let next = try load().pending.values.first(where: { !attempted.contains($0.id) }) else {
                    guard hasPendingResume else { return }
                    hasPendingResume = false
                    attempted.removeAll()
                    continue
                }
                migration = next
            } catch {
                Log.migration.w("legacy battery migration queue could not load", error: error)
                return
            }
            attempted.insert(migration.id)
            do {
                if let authorization = authorizationWorkers[migration.id] {
                    await authorization.task.value
                }
                try Task.checkCancellation()
                guard try load().pending[migration.id]?.requiresAuthorizationRefresh == false else { continue }
                try await migrate(migration)
            } catch {
                guard !Task.isCancelled else { return }
                Log.migration.w("legacy battery migration deferred", error: error)
            }
        }
    }

    private func migrate(_ migration: LegacyBatteryMigration) async throws {
        while true {
            try Task.checkCancellation()
            let waiter = UUID()
            let worker: MigrationWorker
            if let current = migrationWorkers[migration.id] {
                worker = current
            } else {
                let generation = UUID()
                worker = MigrationWorker(generation: generation, task: Task {
                    let result: Result<Void, Error>
                    do {
                        try await self.perform(migration)
                        result = .success(())
                    } catch {
                        result = .failure(error)
                    }
                    self.migrationFinished(migration.id, generation: generation, result: result)
                }, waiters: [:])
                migrationWorkers[migration.id] = worker
            }
            do {
                try await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        guard migrationWorkers[migration.id]?.generation == worker.generation else {
                            continuation.resume(throwing: MigrationError.notReady)
                            return
                        }
                        migrationWorkers[migration.id]?.waiters[waiter] = continuation
                    }
                } onCancel: {
                    Task { await self.cancelMigrationWaiter(migration.id, generation: worker.generation, waiter: waiter) }
                }
            } catch {
                try Task.checkCancellation()
                if worker.isCancelling { continue }
                throw error
            }
            try Task.checkCancellation()
            if !worker.isCancelling { return }
        }
    }

    private func cancelMigrationWaiter(_ id: String, generation: UUID, waiter: UUID) {
        guard migrationWorkers[id]?.generation == generation else { return }
        migrationWorkers[id]?.waiters.removeValue(forKey: waiter)?.resume(throwing: CancellationError())
        if migrationWorkers[id]?.waiters.isEmpty == true {
            migrationWorkers[id]?.isCancelling = true
            migrationWorkers[id]?.task.cancel()
        }
    }

    private func migrationFinished(_ id: String, generation: UUID, result: Result<Void, Error>) {
        guard migrationWorkers[id]?.generation == generation else { return }
        let worker = migrationWorkers.removeValue(forKey: id)
        worker?.waiters.values.forEach { $0.resume(with: result) }
        invalidateOffer(id)
    }

    private func invalidateOffer(_ id: String) {
        migrationOffers.removeValue(forKey: id)
        offerWorkers.removeValue(forKey: id)?.task.cancel()
    }

    private func perform(_ migration: LegacyBatteryMigration) async throws {
        do {
            try Task.checkCancellation()
            if try load().completed.contains(migration.id) { return }
            guard let wallet = await currentWallet(for: migration) else { throw MigrationError.walletUnavailable }
            guard try await dependencies.waitUntilIdle(wallet),
                  let current = await currentWallet(for: migration)
            else { throw MigrationError.notReady }
            let balance = try await dependencies.balance(current)
            try Task.checkCancellation()
            guard let amount = Self.decimal(balance.balance),
                  let reserved = Self.decimal(balance.reserved), reserved.compare(NSDecimalNumber.zero) != .orderedAscending
            else { throw MigrationError.invalidBalance }
            guard reserved == 0 else { throw MigrationError.notReady }
            if amount.compare(NSDecimalNumber.zero) != .orderedDescending {
                try complete(migration)
                await dependencies.refreshBalance(current)
                return
            }
            guard let current = await currentWallet(for: migration) else { throw MigrationError.walletUnavailable }
            try Task.checkCancellation()
            do {
                try await dependencies.migrate(current, migration.proof)
            } catch let error as BatteryAPI.ApiError {
                // `/wallet/migrate` is one-way: 409 means the old account has already moved.
                guard case .badStatus(status: 409, message: _) = error else { throw error }
            }
            try Task.checkCancellation()
            await dependencies.refreshBalance(current)
            try complete(migration)
        } catch {
            try Task.checkCancellation()
            if Self.isAuthorizationError(error) {
                var updated = try load()
                updated.pending[migration.id]?.requiresAuthorizationRefresh = true
                try commit(updated)
            }
            throw error
        }
    }

    private func currentWallet(for migration: LegacyBatteryMigration) async -> Data? {
        for data in await dependencies.wallets() {
            guard let wallet = try? JSONDecoder().decode(Wallet.self, from: data),
                  migration.matches(wallet), wallet.multichainWalletState?.syncState == .synced
            else { continue }
            return data
        }
        return nil
    }

    private func complete(_ migration: LegacyBatteryMigration) throws {
        var updated = try load()
        updated.pending.removeValue(forKey: migration.id)
        updated.completed.insert(migration.id)
        try commit(updated)
        invalidateOffer(migration.id)
    }

    private func load() throws -> LegacyBatteryMigrationStore.State {
        if let state { return state }
        let loaded = try dependencies.load()
        state = loaded
        return loaded
    }

    private func commit(_ updated: LegacyBatteryMigrationStore.State) throws {
        try dependencies.save(updated)
        state = updated
    }

    enum MigrationError: Error {
        case invalidBalance
        case notReady
        case walletUnavailable
    }

    private static func decimal(_ value: String) -> NSDecimalNumber? {
        guard value.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil else { return nil }
        let number = NSDecimalNumber(string: value, locale: Locale(identifier: "en_US_POSIX"))
        return number == .notANumber ? nil : number
    }

    static func isAuthorizationError(_ error: Error) -> Bool {
        if (error as? BatteryAuthorizationError) == .legacyProofUnavailable { return true }
        guard let error = error as? BatteryAPI.ApiError,
              case .badStatus(status: 401, message: _) = error
        else { return false }
        return true
    }
}
