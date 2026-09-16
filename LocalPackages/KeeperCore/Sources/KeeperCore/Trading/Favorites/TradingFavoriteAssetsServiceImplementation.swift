import Foundation
import KeeperCoreComponents
import TKLogging

actor TradingFavoriteAssetsServiceImplementation {
    private let fileSystemVault: FileSystemVault<TradingFavoriteAssetsStore, String>
    private let api: TradingAPI
    private let requestContextProvider: TradingRequestContextProvider
    private let marketItemsCache: InMemoryKeyedCache<String, TradingMarketItem>
    private let nowProvider: @Sendable () -> Date
    private var cachedStore: TradingFavoriteAssetsStore?

    init(
        fileSystemVault: FileSystemVault<TradingFavoriteAssetsStore, String>,
        api: TradingAPI,
        requestContextProvider: TradingRequestContextProvider,
        marketItemsCache: InMemoryKeyedCache<String, TradingMarketItem>,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileSystemVault = fileSystemVault
        self.api = api
        self.requestContextProvider = requestContextProvider
        self.marketItemsCache = marketItemsCache
        self.nowProvider = nowProvider
    }
}

extension TradingFavoriteAssetsServiceImplementation: TradingFavoriteAssetsService {
    var assets: [TradingFavoriteAsset] {
        get async {
            loadStore()
                .items
                .values
                .sorted { lhs, rhs in
                    lhs.addedAt > rhs.addedAt
                }
                .map(\.asset)
        }
    }

    func isFavorite(id: String) async -> Bool {
        loadStore().items[id] != nil
    }

    func setFavorite(_ isFavorite: Bool, context: TradingFavoriteAssetContext) async {
        var store = loadStore()

        if isFavorite {
            var item = store.items[context.id] ?? TradingFavoriteAssetsStore.Item(
                id: context.id,
                addedAt: nowProvider()
            )
            item.apply(context)
            store.items[context.id] = item
        } else {
            store.items[context.id] = nil
        }

        saveStore(store)
    }

    func updateAsset(_ context: TradingFavoriteAssetContext) async {
        var store = loadStore()
        guard var item = store.items[context.id] else {
            return
        }

        item.apply(context)
        store.items[context.id] = item
        saveStore(store)
    }

    func cachedMarketItems(assetIDs: [String]) async -> [String: TradingMarketItem] {
        await marketItemsCache.get(assetIDs)
    }

    func marketItems(assetIDs: [String], forceRefresh: Bool) async -> [String: TradingMarketItem] {
        guard !assetIDs.isEmpty else {
            return [:]
        }

        do {
            let cached = await marketItemsCache.get(assetIDs)
            let missing = forceRefresh ? assetIDs : assetIDs.filter { cached[$0] == nil }
            if !missing.isEmpty {
                let requestContext = await requestContextProvider.makeRequestContext()
                // Backend rejects requests with more than `marketItemsBatchSize`
                // ids, so split the missing ids into fixed-size packs.
                for batch in missing.chunked(into: Constants.marketItemsBatchSize) {
                    let response = try await api.getAssets(
                        requestContext: requestContext,
                        ids: batch
                    )
                    let items = response.items
                        .map(TradingMarketItem.init(item:))
                        .reduce(into: [String: TradingMarketItem]()) { $0[$1.id] = $1 }
                    await marketItemsCache.merge(items)
                }
            }
            let result = await marketItemsCache.get(assetIDs)
            refreshStore(with: result)
            return result
        } catch {
            guard !Task.isCancelled else {
                return [:]
            }
            Log.trade.i("load favorite assets market items failed: \(error.localizedDescription)")
            return [:]
        }
    }
}

private extension TradingFavoriteAssetsServiceImplementation {
    enum Constants {
        static let key = "TradingFavoriteAssets"
        static let marketItemsBatchSize = 10
    }

    func loadStore() -> TradingFavoriteAssetsStore {
        if let cachedStore {
            return cachedStore
        }

        let store: TradingFavoriteAssetsStore
        do {
            store = try fileSystemVault.loadItem(key: Constants.key)
        } catch let error as FileSystemVault<TradingFavoriteAssetsStore, String>.LoadError {
            switch error {
            case .noItem:
                store = TradingFavoriteAssetsStore()
            case .corruptedData, .other:
                Log.trade.i("load favorite assets failed: \(error)")
                store = TradingFavoriteAssetsStore()
            }
        } catch {
            Log.trade.i("load favorite assets failed: \(error)")
            store = TradingFavoriteAssetsStore()
        }

        cachedStore = store
        return store
    }

    func refreshStore(with items: [String: TradingMarketItem]) {
        let store = loadStore()
        var updated = store
        for (id, item) in items {
            updated.items[id]?.apply(
                TradingFavoriteAssetContext(id: id, symbol: item.symbol, imageURL: item.imageURL)
            )
        }

        guard updated != store else {
            return
        }
        saveStore(updated)
    }

    func saveStore(_ store: TradingFavoriteAssetsStore) {
        do {
            try fileSystemVault.saveItem(store, key: Constants.key)
            cachedStore = store
        } catch {
            Log.trade.i("save favorite assets failed: \(error)")
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return isEmpty ? [] : [self]
        }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
