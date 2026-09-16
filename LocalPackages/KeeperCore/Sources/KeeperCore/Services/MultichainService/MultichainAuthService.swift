import Foundation
import TKLogging

/// A single-use challenge plus the wallet proofs signed against it and the current device id.
public typealias MultichainWalletRegisterBatch = (
    challenge: String,
    wallets: [MultichainWalletRegisterItem]
)

/// Device-scoped half of the multichain backend: wallet bindings and push, all guarded by
/// the device JWT. Every call takes the token from the session and retries once through a
/// recovery if the backend rejects it.
public protocol MultichainAuthService: Sendable {
    func deviceId() async throws(MultichainServiceError) -> String
    /// `false` when this install has no device id yet, i.e. the backend cannot hold bindings for it.
    func isDeviceKnown() async -> Bool
    func deviceBindings(walletIds: [String]) async throws(MultichainServiceError) -> DeviceBindings
    /// The batch is built per attempt rather than passed in: the proofs are bound to the device id
    /// and the challenge is single-use, so a recovery that rotates the device has to re-sign both.
    func registerWallets(
        walletId: String,
        makeBatch: @escaping (_ deviceId: String) async throws(MultichainServiceError) -> MultichainWalletRegisterBatch
    ) async throws(MultichainServiceError) -> [MultichainWalletRegisterResult]
    func unregisterWallets(walletIds: [String]) async throws(MultichainServiceError)
    /// Records the detach durably before handing it off, so a synchronous caller (wallet delete)
    /// cannot lose it by terminating mid-request.
    func enqueueUnregisterWallets(walletIds: [String])
    /// Retries detaches that were recorded but never confirmed.
    func flushPendingUnregisters() async
    func subscribePush(
        pushToken: String,
        locale: String?,
        walletIds: [String]
    ) async throws(MultichainServiceError)
    func unsubscribePush() async throws(MultichainServiceError)
}

final class MultichainAuthServiceImplementation: MultichainAuthService {
    private let clientAPI: MultichainAuthClientAPI
    private let deviceAuth: DeviceAuthProviding
    private let pendingUnregisterStore: MultichainPendingUnregisterStore
    private let mutationQueue = WalletBindingMutationQueue()

    init(
        clientAPI: MultichainAuthClientAPI,
        deviceAuth: DeviceAuthProviding,
        pendingUnregisterStore: MultichainPendingUnregisterStore
    ) {
        self.clientAPI = clientAPI
        self.deviceAuth = deviceAuth
        self.pendingUnregisterStore = pendingUnregisterStore
    }

    func deviceId() async throws(MultichainServiceError) -> String {
        try await session().deviceId
    }

    func isDeviceKnown() async -> Bool {
        await deviceAuth.isDeviceKnown()
    }

    func deviceBindings(walletIds: [String]) async throws(MultichainServiceError) -> DeviceBindings {
        try await withDeviceAuth { [clientAPI] token throws(MultichainClientAPIError) in
            try await clientAPI.getDeviceBindings(walletIds: walletIds, deviceJWT: token)
        }
    }

    func registerWallets(
        walletId: String,
        makeBatch: @escaping (String) async throws(MultichainServiceError) -> MultichainWalletRegisterBatch
    ) async throws(MultichainServiceError) -> [MultichainWalletRegisterResult] {
        let task = mutationQueue.enqueue(walletIds: [walletId], intent: .register) { [self] token in
            try await registerWallets(walletId: walletId, token: token, makeBatch: makeBatch)
        }
        return try await mutationValue(task)
    }

    func unregisterWallets(walletIds: [String]) async throws(MultichainServiceError) {
        let task = enqueueUnregister(walletIds: walletIds)
        try await mutationValue(task)
    }

    func enqueueUnregisterWallets(walletIds: [String]) {
        guard !walletIds.isEmpty else { return }
        _ = enqueueUnregister(walletIds: walletIds)
    }

    func flushPendingUnregisters() async {
        let pending = pendingUnregisterStore.load()
        guard !pending.isEmpty else { return }
        guard let task = mutationQueue.enqueuePendingUnregister(
            walletIds: pending,
            operation: { [self] token in
                try await unregisterWallets(token: token)
            }
        ) else {
            return
        }
        do {
            try await mutationValue(task)
        } catch {
            Log.w("🪵 Multichain: pending unregisters flush failed", error: error)
        }
    }

    func subscribePush(
        pushToken: String,
        locale: String?,
        walletIds: [String]
    ) async throws(MultichainServiceError) {
        try await withDeviceAuth { [clientAPI] token throws(MultichainClientAPIError) in
            try await clientAPI.subscribeWalletPush(
                pushToken: pushToken,
                locale: locale,
                walletIds: walletIds,
                deviceJWT: token
            )
        }
    }

    func unsubscribePush() async throws(MultichainServiceError) {
        try await withDeviceAuth { [clientAPI] token throws(MultichainClientAPIError) in
            try await clientAPI.unsubscribeWalletPush(deviceJWT: token)
        }
    }
}

private extension MultichainAuthServiceImplementation {
    static let maxUnregisterBatchSize = 32

    func registerWallets(
        walletId: String,
        token: WalletBindingMutationQueue.Token,
        makeBatch: (String) async throws(MultichainServiceError) -> MultichainWalletRegisterBatch
    ) async throws(MultichainServiceError) -> [MultichainWalletRegisterResult] {
        guard mutationQueue.isCurrent(token, walletId: walletId) else {
            throw .cancelled
        }
        if pendingUnregisterStore.load().contains(walletId) {
            try await unregister(walletIds: [walletId], removeConfirmedFromPending: false)
        }
        guard mutationQueue.isCurrent(token, walletId: walletId) else {
            throw .cancelled
        }

        let session = try await session()
        let batch = try await makeBatch(session.deviceId)
        let results: [MultichainWalletRegisterResult]
        do {
            results = try await register(batch: batch, deviceJWT: session.accessToken)
        } catch {
            guard case .unauthorized = error else {
                throw MultichainServiceError(clientAPIError: error)
            }
            let recovered: DeviceAuthSession
            do {
                recovered = try await deviceAuth.recoverSession(invalidating: session.accessToken)
            } catch {
                throw MultichainServiceError(deviceAuthError: error)
            }
            // A rotated device leaves the proofs unprovable, so the batch is rebuilt for the new
            // device — fresh challenge included — instead of being replayed.
            let replayed = recovered.deviceId == session.deviceId
                ? batch
                : try await makeBatch(recovered.deviceId)
            do {
                results = try await register(batch: replayed, deviceJWT: recovered.accessToken)
            } catch {
                throw MultichainServiceError(clientAPIError: error)
            }
        }
        guard mutationQueue.isCurrent(token, walletId: walletId) else {
            throw .cancelled
        }
        pendingUnregisterStore.remove([walletId])
        return results
    }

    func enqueueUnregister(walletIds: [String]) -> Task<Void, Error> {
        mutationQueue.enqueue(
            walletIds: walletIds,
            intent: .unregister,
            prepare: { [pendingUnregisterStore] in
                pendingUnregisterStore.add(walletIds)
            },
            operation: { [self] token in
                try await unregisterWallets(token: token)
            }
        )
    }

    func unregisterWallets(token: WalletBindingMutationQueue.Token) async throws(MultichainServiceError) {
        let walletIds = mutationQueue.currentWalletIds(for: token)
        guard !walletIds.isEmpty else { return }
        try await unregister(walletIds: walletIds, removeConfirmedFromPending: true, token: token)
    }

    func unregister(
        walletIds: [String],
        removeConfirmedFromPending: Bool,
        token: WalletBindingMutationQueue.Token? = nil
    ) async throws(MultichainServiceError) {
        for chunk in walletIds.chunked(into: Self.maxUnregisterBatchSize) {
            _ = try await withDeviceAuth(requiresStableDevice: true) { [clientAPI] deviceJWT throws(MultichainClientAPIError) in
                try await clientAPI.unregisterWallets(walletIds: chunk, deviceJWT: deviceJWT)
            }
            guard removeConfirmedFromPending else { continue }
            let confirmed = token.map { mutationQueue.currentWalletIds(for: $0, among: chunk) } ?? chunk
            pendingUnregisterStore.remove(confirmed)
        }
    }

    func mutationValue<T>(_ task: Task<T, Error>) async throws(MultichainServiceError) -> T {
        do {
            return try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch let error as MultichainServiceError {
            throw error
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .apiError(message: "wallet binding mutation failed: \(error)")
        }
    }

    func register(
        batch: MultichainWalletRegisterBatch,
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> [MultichainWalletRegisterResult] {
        try await clientAPI.registerWallets(
            challenge: batch.challenge,
            wallets: batch.wallets,
            deviceJWT: deviceJWT
        )
    }

    func session() async throws(MultichainServiceError) -> DeviceAuthSession {
        do {
            return try await deviceAuth.session()
        } catch {
            throw MultichainServiceError(deviceAuthError: error)
        }
    }

    /// The retry lives here rather than in a middleware: `HTTPBody` is single-shot, so a
    /// replay has to rebuild the request, which only the caller can do.
    func withDeviceAuth<T>(
        requiresStableDevice: Bool = false,
        _ operation: (String) async throws(MultichainClientAPIError) -> T
    ) async throws(MultichainServiceError) -> T {
        let session = try await session()
        do {
            return try await operation(session.accessToken)
        } catch {
            guard case .unauthorized = error else {
                throw MultichainServiceError(clientAPIError: error)
            }
            let recovered: DeviceAuthSession
            do {
                recovered = try await deviceAuth.recoverSession(invalidating: session.accessToken)
            } catch {
                throw MultichainServiceError(deviceAuthError: error)
            }
            // A detach is scoped by the JWT's device, so a new device cannot confirm work
            // recorded for the rejected one.
            guard !requiresStableDevice || recovered.deviceId == session.deviceId else {
                throw .apiError(message: "device changed while retrying a device-scoped operation")
            }
            do {
                return try await operation(recovered.accessToken)
            } catch {
                throw MultichainServiceError(clientAPIError: error)
            }
        }
    }
}

private final class WalletBindingMutationQueue: @unchecked Sendable {
    enum Intent {
        case register
        case unregister
    }

    struct Token: Sendable {
        let walletIds: [String]
        let versions: [String: Int]
    }

    private let lock = NSLock()
    private var nextVersion = 0
    private var versions = [String: Int]()
    private var intents = [String: Intent]()
    private var tail: Task<Void, Never>?

    func enqueue<T>(
        walletIds: [String],
        intent: Intent,
        prepare: () -> Void = {},
        operation: @escaping (Token) async throws -> T
    ) -> Task<T, Error> {
        lock.lock()
        defer { lock.unlock() }
        prepare()
        let token = makeToken(walletIds: walletIds, intent: intent)
        return makeTask(token: token, operation: operation)
    }

    func enqueuePendingUnregister<T>(
        walletIds: [String],
        operation: @escaping (Token) async throws -> T
    ) -> Task<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let walletIds = walletIds.filter { intents[$0] == nil }
        guard !walletIds.isEmpty else { return nil }
        let token = makeToken(walletIds: walletIds, intent: .unregister)
        return makeTask(token: token, operation: operation)
    }

    func isCurrent(_ token: Token, walletId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return token.versions[walletId] == versions[walletId]
    }

    func currentWalletIds(for token: Token, among walletIds: [String]? = nil) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let candidates = walletIds ?? token.walletIds
        return candidates.filter { token.versions[$0] == versions[$0] }
    }

    private func makeToken(walletIds: [String], intent: Intent) -> Token {
        var seen = Set<String>()
        let walletIds = walletIds.filter { seen.insert($0).inserted }
        var tokenVersions = [String: Int]()
        for walletId in walletIds {
            nextVersion += 1
            versions[walletId] = nextVersion
            intents[walletId] = intent
            tokenVersions[walletId] = nextVersion
        }
        return Token(walletIds: walletIds, versions: tokenVersions)
    }

    private func makeTask<T>(
        token: Token,
        operation: @escaping (Token) async throws -> T
    ) -> Task<T, Error> {
        let previous = tail
        let task = Task { [weak self] in
            await previous?.value
            defer { self?.complete(token) }
            try Task.checkCancellation()
            return try await operation(token)
        }
        tail = Task {
            _ = await task.result
        }
        return task
    }

    private func complete(_ token: Token) {
        lock.lock()
        defer { lock.unlock() }
        for (walletId, version) in token.versions where versions[walletId] == version {
            versions.removeValue(forKey: walletId)
            intents.removeValue(forKey: walletId)
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension MultichainServiceError {
    init(deviceAuthError error: DeviceAuthError) {
        switch error {
        case .cancelled:
            self = .cancelled
        case .connectionError:
            self = .connectionError
        case let .unauthorized(reason):
            self = .apiError(message: reason)
        case let .failed(message):
            self = .apiError(message: message)
        }
    }
}
