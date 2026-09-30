import BigInt
import Foundation

/// Where the asset a caller is about to render came from: a listing that answered for it, or the
/// cache that stood in when one did not.
public enum MultichainAssetRefreshResult {
    case delivered(MultichainAsset)
    /// The request failed, or the listing no longer carries the asset.
    case cached(MultichainAsset?)

    public var asset: MultichainAsset? {
        switch self {
        case let .delivered(asset):
            asset
        case let .cached(asset):
            asset
        }
    }
}

public struct MultichainAssetBalanceProvider {
    private let balanceService: MultichainService
    private let currencyStore: CurrencyStore
    private let visibilityChangesController: VisibilityChangesController?
    private let cache = Cache()

    public init(
        balanceService: MultichainService,
        currencyStore: CurrencyStore,
        visibilityChangesController: VisibilityChangesController? = nil
    ) {
        self.balanceService = balanceService
        self.currencyStore = currencyStore
        self.visibilityChangesController = visibilityChangesController
    }

    public func cachedAsset(
        for assetId: String,
        wallet: Wallet,
        includingHidden: Bool = true
    ) -> MultichainAsset? {
        cachedAsset(
            for: assetId,
            scope: scope(for: wallet),
            includingHidden: includingHidden
        )
    }

    public func cachedAsset(
        for assetId: String,
        multichainState: MultichainWalletState,
        includingHidden: Bool = true
    ) -> MultichainAsset? {
        cachedAsset(
            for: assetId,
            scope: scope(for: multichainState),
            includingHidden: includingHidden
        )
    }

    public func loadAsset(
        for assetId: String,
        wallet: Wallet,
        includingHidden: Bool
    ) async -> MultichainAsset? {
        await reloadAsset(
            for: assetId,
            wallet: wallet,
            includingHidden: includingHidden
        ).asset
    }

    public func loadAsset(
        for assetId: String,
        multichainState: MultichainWalletState,
        includingHidden: Bool
    ) async -> MultichainAsset? {
        await reloadAsset(
            for: assetId,
            multichainState: multichainState,
            includingHidden: includingHidden
        ).asset
    }

    /// The same request as `loadAsset`, saying whether the listing answered for the asset or the
    /// cache stood in for it — for callers that render the difference.
    public func reloadAsset(
        for assetId: String,
        wallet: Wallet,
        includingHidden: Bool
    ) async -> MultichainAssetRefreshResult {
        guard case let .multichain(state) = wallet.multichain else {
            return .cached(
                cachedAsset(
                    for: assetId,
                    wallet: wallet,
                    includingHidden: includingHidden
                )
            )
        }

        return await reloadAsset(
            for: assetId,
            multichainState: state,
            includingHidden: includingHidden
        )
    }

    public func reloadAsset(
        for assetId: String,
        multichainState: MultichainWalletState,
        includingHidden: Bool
    ) async -> MultichainAssetRefreshResult {
        switch await load(
            for: assetId,
            multichainState: multichainState,
            includingHidden: includingHidden
        ) {
        case let .loaded(asset):
            guard let asset else { return .cached(nil) }
            return .delivered(asset)
        case .absent, .failed:
            return .cached(
                cachedAsset(
                    for: assetId,
                    multichainState: multichainState,
                    includingHidden: includingHidden
                )
            )
        }
    }

    public func loadBalance(
        for assetId: String,
        wallet: Wallet
    ) async -> BigUInt? {
        guard case let .multichain(state) = wallet.multichain else {
            return cachedAsset(for: assetId, wallet: wallet)?.balance
        }
        return await loadBalance(for: assetId, multichainState: state)
    }

    /// Unlike `loadAsset`, a complete listing that does not mention the asset resolves to zero —
    /// the wallet holds none of it. `nil` means the request failed and nothing is cached. Callers
    /// gating on funds must not treat those two cases alike.
    public func loadBalance(
        for assetId: String,
        multichainState: MultichainWalletState
    ) async -> BigUInt? {
        let key = Key(
            cacheId: scope(for: multichainState).cacheId,
            assetId: assetId
        )
        switch await load(
            for: assetId,
            multichainState: multichainState,
            includingHidden: true
        ) {
        case let .loaded(asset):
            return asset?.balance
        case .absent:
            cache.markAbsent(for: key)
            return 0
        case .failed:
            if cache.isKnownAbsent(for: key) {
                return 0
            }
            return cachedAsset(
                for: assetId,
                multichainState: multichainState,
                includingHidden: true
            )?.balance
        }
    }

    /// Fills gaps from an already fetched asset page so a details screen can render a
    /// known balance without waiting for its own request. Existing entries are left
    /// alone: refreshing them is `loadAsset`'s job, which also resolves the visibility
    /// race that a blind overwrite here would lose.
    public func primeCache(
        assets: [MultichainAsset],
        multichainState: MultichainWalletState
    ) {
        let cacheId = scope(for: multichainState).cacheId
        cache.storeIfAbsent(
            assets.map { (Key(cacheId: cacheId, assetId: $0.asset.assetId), $0) },
            clearingKnownAbsence: true
        )
    }

    /// Persisted assets fill gaps without superseding balances or absence confirmed this session.
    public func restoreCache(
        assets: [MultichainAsset],
        multichainState: MultichainWalletState
    ) {
        let cacheId = scope(for: multichainState).cacheId
        cache.storeIfAbsent(
            assets.map { (Key(cacheId: cacheId, assetId: $0.asset.assetId), $0) },
            clearingKnownAbsence: false
        )
    }

    public func applyVisibility(
        isHidden: Bool,
        to asset: MultichainAsset,
        wallet: Wallet
    ) -> MultichainAsset {
        let asset = asset.settingHidden(isHidden)
        return cache.applyVisibility(
            asset,
            for: .init(cacheId: scope(for: wallet).cacheId, assetId: asset.asset.assetId)
        )
    }
}

private extension MultichainAssetBalanceProvider {
    enum LoadOutcome {
        /// The listing contained the asset; nil when it was filtered out as hidden.
        case loaded(MultichainAsset?)
        case absent
        case failed
    }

    func load(
        for assetId: String,
        multichainState: MultichainWalletState,
        includingHidden: Bool
    ) async -> LoadOutcome {
        let currency = currencyStore.state
        let scope = scope(for: multichainState)
        let key = Key(cacheId: scope.cacheId, assetId: assetId)
        let visibilityRevision = cache.visibilityRevision(for: key)

        do {
            guard let asset = try await balanceService.getWalletAsset(
                state: multichainState,
                assetId: assetId,
                currencies: requestedCurrencyCodes(for: currency),
                showHidden: includingHidden
            ) else {
                return .absent
            }
            guard let resolvedAsset = assetApplyingPendingChanges(
                asset,
                assetId: assetId,
                scope: scope,
                includingHidden: includingHidden
            ) else {
                return .loaded(nil)
            }

            return .loaded(
                cache.store(
                    resolvedAsset,
                    for: key,
                    expectedVisibilityRevision: visibilityRevision
                )
            )
        } catch {
            return .failed
        }
    }

    struct Scope {
        let cacheId: String
        let visibilityWalletId: String
    }

    func scope(for wallet: Wallet) -> Scope {
        switch wallet.multichain {
        case let .multichain(state):
            return scope(for: state)
        case .unavailable, .none:
            return Scope(cacheId: wallet.id, visibilityWalletId: wallet.id)
        }
    }

    func scope(for multichainState: MultichainWalletState) -> Scope {
        Scope(
            cacheId: multichainState.accountsIdentifier,
            visibilityWalletId: multichainState.walletId
        )
    }

    func cachedAsset(
        for assetId: String,
        scope: Scope,
        includingHidden: Bool
    ) -> MultichainAsset? {
        let asset = cache.asset(
            for: .init(cacheId: scope.cacheId, assetId: assetId)
        )
        return assetApplyingPendingChanges(
            asset,
            assetId: assetId,
            scope: scope,
            includingHidden: includingHidden
        )
    }

    func assetApplyingPendingChanges(
        _ asset: MultichainAsset?,
        assetId: String,
        scope: Scope,
        includingHidden: Bool
    ) -> MultichainAsset? {
        let resolvedAsset = visibilityChangesController?
            .applyingPendingChanges(
                to: asset.map { [$0] } ?? [],
                walletId: scope.visibilityWalletId
            )
            .first { $0.asset.assetId == assetId } ?? asset
        guard includingHidden || resolvedAsset?.isHidden == false else {
            return nil
        }
        return resolvedAsset
    }

    func requestedCurrencyCodes(for currency: Currency) -> [String] {
        var codes = [currency.code.lowercased()]
        if currency != .defaultCurrency {
            codes.append(Currency.defaultCurrency.code.lowercased())
        }
        return codes
    }
}

private final class Cache {
    private struct Entry {
        let asset: MultichainAsset
        let visibilityRevision: UInt64
    }

    private var entries: [Key: Entry] = [:]
    private var absentKeys: Set<Key> = []
    private let lock = NSLock()

    func asset(for key: Key) -> MultichainAsset? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]?.asset
    }

    func markAbsent(for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        absentKeys.insert(key)
    }

    func isKnownAbsent(for key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return absentKeys.contains(key)
    }

    func visibilityRevision(for key: Key) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]?.visibilityRevision ?? 0
    }

    func store(
        _ asset: MultichainAsset,
        for key: Key,
        expectedVisibilityRevision: UInt64
    ) -> MultichainAsset {
        lock.lock()
        defer { lock.unlock() }

        absentKeys.remove(key)
        let currentEntry = entries[key]
        let assetToStore: MultichainAsset
        if let currentEntry, currentEntry.visibilityRevision != expectedVisibilityRevision {
            assetToStore = asset.settingHidden(currentEntry.asset.isHidden)
        } else {
            assetToStore = asset
        }
        entries[key] = Entry(
            asset: assetToStore,
            visibilityRevision: currentEntry?.visibilityRevision ?? 0
        )
        return assetToStore
    }

    func storeIfAbsent(
        _ newEntries: [(key: Key, asset: MultichainAsset)],
        clearingKnownAbsence: Bool
    ) {
        lock.lock()
        defer { lock.unlock() }

        for newEntry in newEntries {
            if clearingKnownAbsence {
                absentKeys.remove(newEntry.key)
            } else if absentKeys.contains(newEntry.key) {
                continue
            }
            guard entries[newEntry.key] == nil else {
                continue
            }
            entries[newEntry.key] = Entry(
                asset: newEntry.asset,
                visibilityRevision: 0
            )
        }
    }

    func applyVisibility(_ asset: MultichainAsset, for key: Key) -> MultichainAsset {
        lock.lock()
        defer { lock.unlock() }

        absentKeys.remove(key)
        entries[key] = Entry(
            asset: asset,
            visibilityRevision: (entries[key]?.visibilityRevision ?? 0) + 1
        )
        return asset
    }
}

private struct Key: Hashable {
    let cacheId: String
    let assetId: String
}
