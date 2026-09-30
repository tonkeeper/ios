@testable import KeeperCore
import KeeperCoreComponents
import TKTradingAPI
import XCTest

final class TradingFavoriteAssetsServiceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        try super.tearDownWithError()
    }

    func test_setFavorite_addsAssetAndExposesItImmediately() async {
        let service = makeService()
        let context = makeContext(id: "ton/mainnet/jetton/0:aaa", symbol: "AAA")

        await service.setFavorite(true, context: context)
        let assets = await service.assets

        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets[0].id, "ton/mainnet/jetton/0:aaa")
        XCTAssertEqual(assets[0].symbol, "AAA")
        let isFavorite = await service.isFavorite(id: context.id)
        XCTAssertTrue(isFavorite)
    }

    func test_setFavorite_false_removesAsset() async {
        let service = makeService()
        let context = makeContext(id: "ton/mainnet/jetton/0:aaa", symbol: "AAA")

        await service.setFavorite(true, context: context)
        await service.setFavorite(false, context: context)

        let assets = await service.assets
        XCTAssertTrue(assets.isEmpty)
        let isFavorite = await service.isFavorite(id: context.id)
        XCTAssertFalse(isFavorite)
    }

    func test_assets_areSortedByAddedAtDescending() async {
        let dateProvider = TestDateProvider()
        let service = makeService(nowProvider: { dateProvider.now() })

        await service.setFavorite(true, context: makeContext(id: "ton/mainnet/jetton/0:old", symbol: "OLD"))
        await service.setFavorite(true, context: makeContext(id: "ton/mainnet/jetton/0:new", symbol: "NEW"))

        let assets = await service.assets

        XCTAssertEqual(assets.map(\.symbol), ["NEW", "OLD"])
    }

    func test_assets_areUnlimited() async {
        let dateProvider = TestDateProvider()
        let service = makeService(nowProvider: { dateProvider.now() })

        for index in 0 ..< 20 {
            await service.setFavorite(
                true,
                context: makeContext(id: "ton/mainnet/jetton/0:\(index)", symbol: "A\(index)")
            )
        }

        let assets = await service.assets

        XCTAssertEqual(assets.count, 20)
    }

    func test_updateAsset_updatesMetadataOnlyWhenFavorite() async {
        let service = makeService()
        let id = "ton/mainnet/jetton/0:aaa"
        let imageURL = URL(string: "https://example.com/aaa.png")

        await service.updateAsset(makeContext(id: id, symbol: "AAA", imageURL: imageURL))
        let assetsBeforeFavorite = await service.assets
        XCTAssertTrue(assetsBeforeFavorite.isEmpty)

        await service.setFavorite(true, context: makeContext(id: id, symbol: nil))
        await service.updateAsset(makeContext(id: id, symbol: "AAA", imageURL: imageURL))

        let asset = await service.assets.first
        XCTAssertEqual(asset?.symbol, "AAA")
        XCTAssertEqual(asset?.imageURL, imageURL)
    }

    func test_favorites_arePersistedInFileSystemVault() async {
        let context = makeContext(id: "ton/mainnet/jetton/0:aaa", symbol: "AAA")
        let firstService = makeService()

        await firstService.setFavorite(true, context: context)

        let secondService = makeService()
        let assets = await secondService.assets

        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets[0].id, context.id)
        let isFavorite = await secondService.isFavorite(id: context.id)
        XCTAssertTrue(isFavorite)
    }

    // MARK: - marketItems gap-fetch / force-refresh

    func test_marketItems_fetchesOnlyMissingIDs_whenNotForced() async {
        let env = makeEnvironment()
        let seeded = makeMarketItem(id: "A", symbol: "AAA", change: "1.0")
        await env.cache.merge(["A": seeded])
        await env.api.setResponse(makeResponse([(id: "B", symbol: "BBB", change: "2.0")]))

        let result = await env.service.marketItems(assetIDs: ["A", "B"], forceRefresh: false)

        let requestedIDs = await env.api.getAssetsIDs
        XCTAssertEqual(requestedIDs, [["B"]])
        XCTAssertEqual(result["A"]?.change24hPercent, Decimal(string: "1.0"))
        XCTAssertEqual(result["B"]?.change24hPercent, Decimal(string: "2.0"))
    }

    func test_marketItems_forceRefresh_refetchesAllAndOverwritesCache() async {
        let env = makeEnvironment()
        let stale = makeMarketItem(id: "A", symbol: "AAA", change: "1.0")
        await env.cache.merge(["A": stale])
        await env.api.setResponse(makeResponse([(id: "A", symbol: "AAA", change: "2.0")]))

        let result = await env.service.marketItems(assetIDs: ["A"], forceRefresh: true)

        let requestedIDs = await env.api.getAssetsIDs
        XCTAssertEqual(requestedIDs, [["A"]])
        XCTAssertEqual(result["A"]?.change24hPercent, Decimal(string: "2.0"))
        let cached = await env.cache.get(["A"])
        XCTAssertEqual(cached["A"]?.change24hPercent, Decimal(string: "2.0"))
    }

    func test_marketItems_batchesRequestsIntoPacksOfTen() async {
        let env = makeEnvironment()
        let ids = (0 ..< 25).map { "id-\($0)" }
        await env.api.setResponse(makeResponse([] as [(id: String, symbol: String, change: String)]))

        _ = await env.service.marketItems(assetIDs: ids, forceRefresh: true)

        // Backend rejects batches larger than 10, so the request is split into
        // fixed-size packs covering every id in order.
        let requestedIDs = await env.api.getAssetsIDs
        XCTAssertEqual(requestedIDs.map(\.count), [10, 10, 5])
        XCTAssertEqual(requestedIDs.flatMap { $0 }, ids)
    }

    func test_marketItems_emptyIDs_doesNotCallAPI() async {
        let env = makeEnvironment()

        let result = await env.service.marketItems(assetIDs: [], forceRefresh: true)

        XCTAssertTrue(result.isEmpty)
        let requestedIDs = await env.api.getAssetsIDs
        XCTAssertTrue(requestedIDs.isEmpty)
    }

    func test_marketItems_failure_leavesCacheAndStoreUnchanged() async {
        let env = makeEnvironment()
        await env.service.setFavorite(true, context: makeContext(id: "A", symbol: "OLD"))
        await env.api.setError(.transportError(underlying: nil))

        let result = await env.service.marketItems(assetIDs: ["A"], forceRefresh: true)

        XCTAssertTrue(result.isEmpty)
        let cached = await env.service.cachedMarketItems(assetIDs: ["A"])
        XCTAssertTrue(cached.isEmpty)
        let asset = await env.service.assets.first
        XCTAssertEqual(asset?.symbol, "OLD")
    }

    func test_marketItems_persistsFreshSymbolAndImageToStore() async {
        let oldImage = URL(string: "https://example.com/old.png")
        let newImage = "https://example.com/new.png"
        let env = makeEnvironment()
        await env.service.setFavorite(
            true,
            context: makeContext(id: "A", symbol: "OLD", imageURL: oldImage)
        )
        await env.api.setResponse(
            makeResponse([(id: "A", symbol: "NEW", change: "1.0", image: newImage)])
        )

        _ = await env.service.marketItems(assetIDs: ["A"], forceRefresh: true)

        let reloaded = makeService()
        let asset = await reloaded.assets.first
        XCTAssertEqual(asset?.symbol, "NEW")
        XCTAssertEqual(asset?.imageURL, URL(string: newImage))
    }

    func test_marketItems_doesNotPersistNonFavoriteItems() async {
        let env = makeEnvironment()
        await env.service.setFavorite(true, context: makeContext(id: "A", symbol: "OLD"))
        await env.api.setResponse(
            makeResponse([
                (id: "A", symbol: "NEW", change: "1.0"),
                (id: "B", symbol: "BBB", change: "2.0"),
            ])
        )

        _ = await env.service.marketItems(assetIDs: ["A", "B"], forceRefresh: true)

        let reloaded = makeService()
        let assets = await reloaded.assets
        XCTAssertEqual(assets.map(\.id), ["A"])
        XCTAssertEqual(assets.first?.symbol, "NEW")
    }
}

private extension TradingFavoriteAssetsServiceTests {
    struct Environment {
        let service: TradingFavoriteAssetsServiceImplementation
        let api: TradingAPISpy
        let cache: InMemoryKeyedCache<String, TradingMarketItem>
    }

    func makeEnvironment(
        nowProvider: @escaping @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1000)
        }
    ) -> Environment {
        let api = TradingAPISpy()
        let cache = InMemoryKeyedCache<String, TradingMarketItem>()
        let service = TradingFavoriteAssetsServiceImplementation(
            fileSystemVault: FileSystemVault<TradingFavoriteAssetsStore, String>(
                fileManager: .default,
                directory: directory
            ),
            api: api,
            requestContextProvider: RequestContextProviderStub(),
            marketItemsCache: cache,
            nowProvider: nowProvider
        )
        return Environment(service: service, api: api, cache: cache)
    }

    func makeService(
        nowProvider: @escaping @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1000)
        }
    ) -> TradingFavoriteAssetsServiceImplementation {
        makeEnvironment(nowProvider: nowProvider).service
    }

    func makeContext(
        id: String,
        symbol: String?,
        imageURL: URL? = nil
    ) -> TradingFavoriteAssetContext {
        TradingFavoriteAssetContext(
            id: id,
            symbol: symbol,
            imageURL: imageURL
        )
    }

    func makeMarketItem(
        id: String,
        symbol: String,
        change: String,
        imageURL: URL? = nil
    ) -> TradingMarketItem {
        TradingMarketItem(
            id: id,
            symbol: symbol,
            name: symbol,
            category: .tokens,
            imageURL: imageURL,
            price: nil,
            change24hPercent: Decimal(string: change),
            verification: .whitelist
        )
    }

    func makeResponse(
        _ items: [(id: String, symbol: String, change: String)]
    ) -> Components.Schemas.AssetsCatalogResponse {
        makeResponse(items.map { ($0.id, $0.symbol, $0.change, "https://example.com/\($0.id).png") })
    }

    func makeResponse(
        _ items: [(id: String, symbol: String, change: String, image: String)]
    ) -> Components.Schemas.AssetsCatalogResponse {
        Components.Schemas.AssetsCatalogResponse(
            items: items.map { item in
                Components.Schemas.MarketItem(
                    asset: Components.Schemas.AssetRefSummary(
                        asset_type: .asset,
                        id: item.id,
                        symbol: item.symbol,
                        name: item.symbol,
                        decimals: 9,
                        trust_score: 100,
                        image_url: item.image,
                        is_scam: false,
                        verification: .whitelist
                    ),
                    metrics: Components.Schemas.MarketMetricsSummary(
                        volume: "0",
                        price: "1.0",
                        change_24h_percent: item.change,
                        provider: "test",
                        as_of: Date(timeIntervalSince1970: 1000)
                    )
                )
            },
            data_freshness_sec: 0
        )
    }
}

private actor TradingAPISpy: TradingAPI {
    private(set) var getAssetsIDs = [[String]]()
    private var response: Components.Schemas.AssetsCatalogResponse?
    private var error: TradingAPIError?

    func setResponse(_ response: Components.Schemas.AssetsCatalogResponse) {
        self.response = response
    }

    func setError(_ error: TradingAPIError) {
        self.error = error
    }

    func getShelves(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponse {
        fatalError("unused")
    }

    func getAssetsCatalog(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        fatalError("unused")
    }

    func getAssets(
        requestContext: TradingRequestContext,
        ids: [String]
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        getAssetsIDs.append(ids)
        if let error {
            throw error
        }
        return response ?? Components.Schemas.AssetsCatalogResponse(items: [], data_freshness_sec: 0)
    }

    func getAssetChart(
        requestContext: TradingRequestContext,
        assetId: String,
        period: Period,
        currency: Currency
    ) async throws(TradingAPIError) -> [Coordinate] {
        fatalError("unused")
    }

    func getShelvesV2(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponseV2 {
        fatalError("unused")
    }

    func getAssetsCatalogV2(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        sort: Components.Schemas.AssetsSort?,
        order: Components.Schemas.AssetsOrder?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?,
        showPerps _: Bool?,
        chain _: String?,
        filter _: Components.Schemas.AssetsFilter?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        fatalError("unused")
    }

    func getAssetsDetailsV2(
        requestContext: TradingRequestContext,
        assetId: String
    ) async throws(TradingAPIError) -> Components.Schemas.AssetDetailsResponse {
        fatalError("unused")
    }
}

private struct RequestContextProviderStub: TradingRequestContextProvider {
    func makeRequestContext() async -> TradingRequestContext {
        TradingRequestContext(
            currency: .USD,
            language: "en",
            userAgent: "test",
            storeCountryCode: nil,
            simCountryCode: nil,
            deviceCountryCode: nil,
            timezoneIdentifier: "UTC",
            isVPNActive: nil
        )
    }
}

private final class TestDateProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var timestamp: TimeInterval = 1000

    func now() -> Date {
        lock.lock()
        defer {
            lock.unlock()
        }

        let date = Date(timeIntervalSince1970: timestamp)
        timestamp += 1
        return date
    }
}
