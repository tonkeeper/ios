import Foundation
import TKLogging

public protocol WalletAuthTokenProviding: Sendable {
    /// The `X-Wallet-Authorization` credential for one wallet, or `nil` when this install cannot
    /// sign for it yet. A caller that gets `nil` sends the request without the header.
    func token(walletId: String, accessToken: String) async -> String?
    /// Drops the credential minted for this wallet, in memory and in the Keychain, so the next
    /// `token` call signs a fresh one. The app key is kept: it is what makes reminting free.
    func invalidateToken(walletId: String) async
    /// Whether a durable app key is already kept for this wallet (memory or Keychain). An ephemeral
    /// lease does not count: it would still need a passcode-gated warm to survive a relaunch.
    func hasPersistentAppKey(walletId: String) async -> Bool
    /// Derives and keeps the wallet's app key so later tokens need no passcode. Called from the
    /// paths that already hold a mnemonic.
    func warm(walletId: String, mnemonic: String) async
    func forget(walletId: String) async
    func wipe() async
}

protocol WalletAuthEphemeralKeyProviding: Sendable {
    /// Makes a wallet app key available only in memory for the lifetime of `operation`. A
    /// persistent key is reused, and a derivation failure runs the operation without wallet auth.
    func withEphemeralKey<T: Sendable>(
        walletId: String,
        mnemonic: String,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T
}

/// Mints and caches the wallet-scoped credential the backend reads as `X-Wallet-Authorization`.
///
/// Deriving the app key costs a passcode, but signing with it does not, and the token has to be
/// reissued every time the device access token rotates. Keeping the key is what makes those
/// reissues invisible, and keeping it in the Keychain is what makes a relaunch cost no passcode
/// either. Both maps below are the in-memory mirror of that storage.
actor WalletAuthTokenProvider: WalletAuthTokenProviding, WalletAuthEphemeralKeyProviding {
    private enum AppKey {
        case persistent(Data)
        case ephemeral(Data)

        var data: Data {
            switch self {
            case let .persistent(data), let .ephemeral(data):
                return data
            }
        }

        var isPersistent: Bool {
            if case .persistent = self {
                return true
            }
            return false
        }
    }

    private struct EphemeralKey {
        var data: Data
        var leaseIds: Set<UUID>
    }

    /// Resolved on first use rather than held: this provider is owned above `MultichainAssembly`,
    /// because the battery needs it too and reaching it through that assembly would close a cycle
    /// over `ServicesAssembly`/`BatteryAssembly`. `nil` once the owning graph is gone — a caller
    /// that keeps a service but drops the assembly leaves this provider behind it, and a request
    /// without the wallet credential beats aborting the process.
    private let resolveChainKitService: @Sendable () -> ChainKitService?
    private let store: WalletAuthKeychainStore

    private var appKeys = [String: Data]()
    private var ephemeralKeys = [String: EphemeralKey]()
    /// Wallets the Keychain conclusively has no key for, so the next request skips it. A Keychain
    /// that could not be read at all (locked device) is deliberately absent here: it gets retried.
    private var walletsWithoutAppKey = Set<String>()
    private var tokens = [String: String]()

    init(
        chainKitService: @escaping @Sendable () -> ChainKitService?,
        store: WalletAuthKeychainStore
    ) {
        resolveChainKitService = chainKitService
        self.store = store
    }

    func token(walletId: String, accessToken: String) -> String? {
        guard !walletId.isEmpty, !accessToken.isEmpty else {
            return nil
        }

        let key = Self.cacheKey(walletId: walletId, accessToken: accessToken)
        if let cached = tokens[key] {
            return cached
        }

        // A token outlives nothing but the access token it signs, so a miss is the moment to drop
        // everything minted for an earlier one rather than let the map grow across rotations.
        tokens = tokens.filter { $0.key.hasSuffix(Self.suffix(accessToken: accessToken)) }

        let appKey = appKey(walletId: walletId)
        // Neither half can be there: the two items are written together, so a wallet the Keychain
        // has no key for has no token either, and reading for one is wasted on every request.
        if appKey == nil, walletsWithoutAppKey.contains(walletId) {
            return nil
        }

        let fingerprint = WalletAuthKeychainStore.fingerprint(accessToken: accessToken)
        // A preview credential is intentionally memory-only, so it must neither consume nor update
        // the persistent token record.
        if appKey?.isPersistent != false,
           let stored = store.loadToken(walletId: walletId),
           stored.accessTokenFingerprint == fingerprint
        {
            tokens[key] = stored.token
            return stored.token
        }

        guard let appKey else {
            return nil
        }

        guard let chainKitService = resolveChainKitService() else {
            Log.w("🪵 WalletAuth: no chain kit service, request goes unsigned")
            return nil
        }

        let token = chainKitService.walletAuthToken(
            appPrivateKey: appKey.data,
            accessToken: accessToken
        )
        tokens[key] = token
        if appKey.isPersistent {
            store.saveToken(
                WalletAuthKeychainStore.TokenRecord(accessTokenFingerprint: fingerprint, token: token),
                walletId: walletId
            )
        }
        return token
    }

    func invalidateToken(walletId: String) {
        guard !walletId.isEmpty else {
            return
        }
        removeCachedTokens(walletId: walletId)
        store.deleteToken(walletId: walletId)
    }

    func hasPersistentAppKey(walletId: String) -> Bool {
        guard !walletId.isEmpty else {
            return false
        }
        if appKeys[walletId] != nil {
            return true
        }
        if walletsWithoutAppKey.contains(walletId) {
            return false
        }
        do {
            guard let stored = try store.loadAppKey(walletId: walletId) else {
                walletsWithoutAppKey.insert(walletId)
                return false
            }
            appKeys[walletId] = stored
            return true
        } catch {
            // A locked Keychain is not absence: do not remember it, and let the unlock path retry.
            Log.w("🪵 WalletAuth: load app key failed", error: error)
            return false
        }
    }

    func warm(walletId: String, mnemonic: String) {
        guard !walletId.isEmpty else {
            return
        }
        switch appKey(walletId: walletId) {
        case .persistent:
            return
        case let .ephemeral(appPrivateKey):
            ephemeralKeys.removeValue(forKey: walletId)
            appKeys[walletId] = appPrivateKey
            walletsWithoutAppKey.remove(walletId)
            store.saveAppKey(appPrivateKey, walletId: walletId)
            return
        case nil:
            break
        }
        guard let chainKitService = resolveChainKitService() else {
            Log.w("🪵 WalletAuth: no chain kit service, app key not warmed")
            return
        }
        do {
            let appPrivateKey = try chainKitService.walletAppPrivateKey(mnemonic: mnemonic)
            appKeys[walletId] = appPrivateKey
            walletsWithoutAppKey.remove(walletId)
            // A refused write costs the next launch a passcode, not this session: the key above
            // serves it either way.
            store.saveAppKey(appPrivateKey, walletId: walletId)
        } catch {
            Log.w("🪵 WalletAuth: failed to derive app key", error: error)
        }
    }

    func withEphemeralKey<T: Sendable>(
        walletId: String,
        mnemonic: String,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let leaseId = beginEphemeralKey(walletId: walletId, mnemonic: mnemonic)
        defer {
            if let leaseId {
                endEphemeralKey(walletId: walletId, leaseId: leaseId)
            }
        }
        return try await operation()
    }

    private func beginEphemeralKey(walletId: String, mnemonic: String) -> UUID? {
        guard !walletId.isEmpty else {
            return nil
        }
        if case .persistent = appKey(walletId: walletId) {
            return nil
        }

        let leaseId = UUID()
        if var existing = ephemeralKeys[walletId] {
            existing.leaseIds.insert(leaseId)
            ephemeralKeys[walletId] = existing
            return leaseId
        }

        guard let chainKitService = resolveChainKitService() else {
            Log.w("🪵 WalletAuth: no chain kit service, no ephemeral key")
            return nil
        }
        do {
            let appPrivateKey = try chainKitService.walletAppPrivateKey(mnemonic: mnemonic)
            ephemeralKeys[walletId] = EphemeralKey(data: appPrivateKey, leaseIds: [leaseId])
            return leaseId
        } catch {
            Log.w("🪵 WalletAuth: failed to derive ephemeral app key", error: error)
            return nil
        }
    }

    private func endEphemeralKey(walletId: String, leaseId: UUID) {
        guard var key = ephemeralKeys[walletId], key.leaseIds.remove(leaseId) != nil else {
            return
        }
        guard key.leaseIds.isEmpty else {
            ephemeralKeys[walletId] = key
            return
        }
        ephemeralKeys.removeValue(forKey: walletId)
        key.data.resetBytes(in: 0 ..< key.data.count)
        removeCachedTokens(walletId: walletId)
    }

    func forget(walletId: String) {
        zeroAppKey(walletId: walletId)
        zeroEphemeralKey(walletId: walletId)
        walletsWithoutAppKey.insert(walletId)
        removeCachedTokens(walletId: walletId)
        store.delete(walletId: walletId)
    }

    func wipe() {
        for walletId in appKeys.keys {
            zeroAppKey(walletId: walletId)
        }
        for walletId in ephemeralKeys.keys {
            zeroEphemeralKey(walletId: walletId)
        }
        walletsWithoutAppKey.removeAll()
        tokens.removeAll()
        store.deleteAll()
    }
}

private extension WalletAuthTokenProvider {
    static func cacheKey(walletId: String, accessToken: String) -> String {
        "\(walletId)\(suffix(accessToken: accessToken))"
    }

    static func suffix(accessToken: String) -> String {
        "_\(accessToken)"
    }

    private func appKey(walletId: String) -> AppKey? {
        if let cached = appKeys[walletId] {
            return .persistent(cached)
        }
        if let ephemeral = ephemeralKeys[walletId] {
            return .ephemeral(ephemeral.data)
        }
        guard !walletsWithoutAppKey.contains(walletId) else {
            return nil
        }
        do {
            guard let stored = try store.loadAppKey(walletId: walletId) else {
                walletsWithoutAppKey.insert(walletId)
                return nil
            }
            appKeys[walletId] = stored
            return .persistent(stored)
        } catch {
            Log.w("🪵 WalletAuth: load app key failed", error: error)
            return nil
        }
    }

    func zeroAppKey(walletId: String) {
        guard var key = appKeys.removeValue(forKey: walletId) else {
            return
        }
        key.resetBytes(in: 0 ..< key.count)
    }

    func zeroEphemeralKey(walletId: String) {
        guard var key = ephemeralKeys.removeValue(forKey: walletId)?.data else {
            return
        }
        key.resetBytes(in: 0 ..< key.count)
    }

    func removeCachedTokens(walletId: String) {
        tokens = tokens.filter { !$0.key.hasPrefix("\(walletId)_") }
    }
}
