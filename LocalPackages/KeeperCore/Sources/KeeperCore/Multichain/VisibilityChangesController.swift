@preconcurrency import BigInt
import Foundation
import KeeperCoreComponents

public final class VisibilityChangesController {
    typealias Vault = FileSystemVault<PendingVisibilityChangesStore, String>

    private let vault: Vault
    private let writer: MultichainAssetVisibilityChangesWriter
    private let lock = NSLock()
    private var retryTasks = [String: Task<Void, Never>]()
    private var sentChanges = [String: [SentVisibilityChange]]()
    private var activeFetchTokens = [String: [UInt64]]()
    private var latestCompletedFetchTokens = [String: UInt64]()
    private var sendGeneration: UInt64 = 0

    init(
        vault: Vault,
        writer: MultichainAssetVisibilityChangesWriter
    ) {
        self.vault = vault
        self.writer = writer
    }

    public func enqueue(
        _ changes: [MultichainAssetFilterChange],
        walletId: String,
        assets: [MultichainAsset]
    ) throws {
        guard !changes.isEmpty else { return }

        try locked {
            var store = loadStore(walletId: walletId) ?? PendingVisibilityChangesStore()
            store.merge(changes: changes, assets: assets)
            try saveStore(store, walletId: walletId)
        }
        retryPendingChanges(walletId: walletId)
    }

    public func retryPendingChanges(walletId: String) {
        let changes: [MultichainAssetFilterChange] = locked {
            guard retryTasks[walletId] == nil else { return [] }
            guard let store = loadStore(walletId: walletId), !store.changes.isEmpty else { return [] }

            let changes = store.changes.map(\.filterChange)
            retryTasks[walletId] = Task { [weak self] in
                await self?.sendPendingChanges(changes, walletId: walletId)
            }
            return changes
        }
        guard !changes.isEmpty else { return }
    }

    public func pendingSnapshot(walletId: String) -> VisibilityChangesSnapshot {
        locked {
            VisibilityChangesSnapshot(
                store: loadStore(walletId: walletId),
                sentChanges: sentChanges[walletId] ?? []
            )
        }
    }

    func beginServerFetch(walletId: String) -> UInt64 {
        locked {
            let token = sendGeneration
            activeFetchTokens[walletId, default: []].append(token)
            return token
        }
    }

    func cancelServerFetch(walletId: String, token: UInt64) {
        locked {
            removeActiveFetchToken(token, walletId: walletId)
            pruneSentChanges(walletId: walletId)
        }
    }

    func endServerFetch(walletId: String, token: UInt64) {
        locked {
            removeActiveFetchToken(token, walletId: walletId)
            latestCompletedFetchTokens[walletId] = max(
                token,
                latestCompletedFetchTokens[walletId] ?? token
            )
            pruneSentChanges(walletId: walletId)
        }
    }

    public func applyingPendingChanges(
        to assets: [MultichainAsset],
        walletId: String
    ) -> [MultichainAsset] {
        applyingPendingChanges(
            to: assets,
            snapshot: pendingSnapshot(walletId: walletId)
        )
    }

    public func applyingPendingChanges(
        to assets: [MultichainAsset],
        snapshot: VisibilityChangesSnapshot
    ) -> [MultichainAsset] {
        guard snapshot.hasChanges else {
            return assets
        }

        let pendingChanges = snapshot.store?.changes ?? []
        var actionsByAssetId = [String: MultichainAssetFilterAction]()
        var assetSnapshotsByAssetId = [String: StoredMultichainAsset]()
        for sent in snapshot.sentChanges {
            actionsByAssetId[sent.change.assetId] = sent.change.action
            if let asset = sent.asset {
                assetSnapshotsByAssetId[sent.change.assetId] = asset
            }
        }
        for change in pendingChanges {
            actionsByAssetId[change.assetId] = change.action
        }
        for asset in snapshot.store?.assets ?? [] {
            assetSnapshotsByAssetId[asset.assetId] = asset
        }

        var result = assets.map { asset in
            guard let action = actionsByAssetId[asset.asset.assetId] else {
                return asset
            }
            return asset.settingHidden(action == .hide)
        }

        var knownAssetIds = Set(result.map(\.asset.assetId))
        for change in snapshot.sentChanges.map(\.change) + pendingChanges {
            guard actionsByAssetId[change.assetId] == .show,
                  !knownAssetIds.contains(change.assetId),
                  let asset = assetSnapshotsByAssetId[change.assetId]?.asset?.settingHidden(false)
            else { continue }
            result.append(asset)
            knownAssetIds.insert(change.assetId)
        }

        return result
    }
}

protocol MultichainAssetVisibilityChangesWriter {
    func saveWalletAssetsFilters(
        walletId: String,
        changes: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError)
}

struct MultichainAssetVisibilityChangesClientWriter: MultichainAssetVisibilityChangesWriter {
    let multichainClientAPI: MultichainClientAPI

    func saveWalletAssetsFilters(
        walletId: String,
        changes: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {
        do {
            try await multichainClientAPI.saveWalletAssetsFilters(
                walletId: walletId,
                changes: changes
            )
        } catch {
            throw MultichainServiceError(clientAPIError: error)
        }
    }
}

public struct VisibilityChangesSnapshot: Sendable {
    fileprivate let store: PendingVisibilityChangesStore?
    fileprivate let sentChanges: [SentVisibilityChange]

    public var hasChanges: Bool {
        if let store, !store.changes.isEmpty {
            return true
        }
        return !sentChanges.isEmpty
    }
}

private extension VisibilityChangesController {
    func sendPendingChanges(
        _ changes: [MultichainAssetFilterChange],
        walletId: String
    ) async {
        var didSendChanges = false
        do {
            try await writer.saveWalletAssetsFilters(
                walletId: walletId,
                changes: changes
            )
            didSendChanges = true
        } catch {}

        locked {
            if didSendChanges {
                completeSentChanges(changes, walletId: walletId)
            }
            retryTasks[walletId] = nil
        }
        if didSendChanges {
            retryPendingChanges(walletId: walletId)
        }
    }

    func locked<T>(_ block: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }

    func loadStore(walletId: String) -> PendingVisibilityChangesStore? {
        do {
            return try vault.loadItem(key: vaultKey(walletId: walletId))
        } catch {
            return nil
        }
    }

    func saveStore(_ store: PendingVisibilityChangesStore, walletId: String) throws {
        let key = vaultKey(walletId: walletId)
        if store.changes.isEmpty {
            try? vault.deleteItem(key: key)
        } else {
            try vault.saveItem(store, key: key)
        }
    }

    func vaultKey(walletId: String) -> String {
        Data(walletId.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func completeSentChanges(
        _ changes: [MultichainAssetFilterChange],
        walletId: String
    ) {
        let store = loadStore(walletId: walletId)
        let assetsById = Dictionary(
            uniqueKeysWithValues: (store?.assets ?? []).map { ($0.assetId, $0) }
        )

        sendGeneration += 1
        var retained = sentChanges[walletId] ?? []
        for change in changes {
            retained.removeAll { $0.change.assetId == change.assetId }
            retained.append(
                SentVisibilityChange(
                    change: StoredVisibilityChange(assetId: change.assetId, action: change.action),
                    asset: assetsById[change.assetId],
                    generation: sendGeneration
                )
            )
        }
        sentChanges[walletId] = retained

        guard var remainingStore = store else { return }
        let sentActions = Dictionary(
            uniqueKeysWithValues: changes.map { ($0.assetId, $0.action) }
        )
        remainingStore.changes.removeAll { sentActions[$0.assetId] == $0.action }
        let remainingAssetIds = Set(remainingStore.changes.map(\.assetId))
        remainingStore.assets.removeAll { !remainingAssetIds.contains($0.assetId) }
        try? saveStore(remainingStore, walletId: walletId)
    }

    func removeActiveFetchToken(_ token: UInt64, walletId: String) {
        guard
            var tokens = activeFetchTokens[walletId],
            let index = tokens.firstIndex(of: token)
        else { return }
        tokens.remove(at: index)
        activeFetchTokens[walletId] = tokens.isEmpty ? nil : tokens
    }

    func pruneSentChanges(walletId: String) {
        guard var retained = sentChanges[walletId],
              let latestCompletedFetchToken = latestCompletedFetchTokens[walletId]
        else { return }
        let threshold = min(
            latestCompletedFetchToken,
            activeFetchTokens[walletId]?.min() ?? .max
        )
        retained.removeAll { $0.generation <= threshold }
        sentChanges[walletId] = retained.isEmpty ? nil : retained
    }
}

struct PendingVisibilityChangesStore: Codable {
    var changes = [StoredVisibilityChange]()
    var assets = [StoredMultichainAsset]()

    mutating func merge(
        changes newChanges: [MultichainAssetFilterChange],
        assets newAssets: [MultichainAsset]
    ) {
        var order = changes.map(\.assetId)
        var actions = Dictionary(uniqueKeysWithValues: changes.map { ($0.assetId, $0.action) })

        for change in newChanges {
            if actions[change.assetId] == nil {
                order.append(change.assetId)
            }
            actions[change.assetId] = change.action
        }

        changes = order.compactMap { assetId in
            actions[assetId].map {
                StoredVisibilityChange(assetId: assetId, action: $0)
            }
        }

        let changedAssetIds = Set(newChanges.map(\.assetId))
        var assetsById = Dictionary(uniqueKeysWithValues: assets.map { ($0.assetId, $0) })
        for asset in newAssets where changedAssetIds.contains(asset.asset.assetId) {
            assetsById[asset.asset.assetId] = StoredMultichainAsset(asset)
        }
        assets = changes.compactMap { assetsById[$0.assetId] }
    }
}

struct StoredVisibilityChange: Codable {
    let assetId: String
    let action: MultichainAssetFilterAction

    var filterChange: MultichainAssetFilterChange {
        MultichainAssetFilterChange(assetId: assetId, action: action)
    }
}

struct SentVisibilityChange {
    let change: StoredVisibilityChange
    let asset: StoredMultichainAsset?
    let generation: UInt64
}

struct StoredMultichainAsset: Codable {
    let assetId: String
    let name: String
    let symbol: String
    let decimals: Int
    let image: String
    let verification: MultichainAssetVerification
    let prices: [String: Double]
    let diff24h: [String: String]
    let diff7d: [String: String]
    let diff30d: [String: String]
    let isHidden: Bool
    let balance: String
    let marketCap: [String: String]

    init(_ asset: MultichainAsset) {
        assetId = asset.asset.assetId
        name = asset.asset.name
        symbol = asset.asset.symbol
        decimals = asset.asset.decimals
        image = asset.asset.image
        verification = asset.asset.verification
        prices = asset.price.prices
        diff24h = asset.price.diff24h
        diff7d = asset.price.diff7d
        diff30d = asset.price.diff30d
        isHidden = asset.isHidden
        balance = asset.balance.description
        marketCap = asset.marketCap
    }

    var asset: MultichainAsset? {
        guard let balance = BigUInt(balance) else { return nil }
        return MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: name,
                symbol: symbol,
                decimals: decimals,
                image: image,
                verification: verification
            ),
            price: MultichainAssetPrice(
                prices: prices,
                diff24h: diff24h,
                diff7d: diff7d,
                diff30d: diff30d
            ),
            isHidden: isHidden,
            balance: balance,
            marketCap: marketCap
        )
    }
}

extension MultichainAsset {
    func settingHidden(_ isHidden: Bool) -> MultichainAsset {
        MultichainAsset(
            asset: asset,
            price: price,
            isHidden: isHidden,
            balance: balance,
            marketCap: marketCap
        )
    }
}
