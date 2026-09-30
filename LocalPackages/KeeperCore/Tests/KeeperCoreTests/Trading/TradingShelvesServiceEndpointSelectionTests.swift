@testable import KeeperCore
import TKTradingAPI
import XCTest

final class TradingShelvesServiceEndpointSelectionTests: XCTestCase {
    func test_loadShelves_forLegacyMode_callsV1Endpoint() async {
        let api = TradingShelvesAPISpy()
        let service = makeService(api: api)

        await assertNetworkError {
            _ = try await service.loadShelves(for: .legacy)
        }
        let calls = await api.calls()

        XCTAssertEqual(calls, [.getShelves])
    }

    func test_loadShelves_forMultichainMode_callsV2Endpoint() async {
        let api = TradingShelvesAPISpy()
        let service = makeService(api: api)

        await assertNetworkError {
            _ = try await service.loadShelves(for: .multichain)
        }
        let calls = await api.calls()

        XCTAssertEqual(calls, [.getShelvesV2])
    }

    func test_shelves_keepsSnapshotsIsolatedByMode() async {
        let cache = InMemoryKeyedCache<TradingShelvesMode, TradingShelvesSnapshot>()
        let legacySnapshot = TradingShelvesSnapshot(
            generatedAt: .now,
            currency: .USD,
            shelves: []
        )
        let multichainSnapshot = TradingShelvesSnapshot(
            generatedAt: .distantPast,
            currency: .EUR,
            shelves: []
        )
        await cache.set(legacySnapshot, for: .legacy)
        await cache.set(multichainSnapshot, for: .multichain)
        let service = makeService(api: TradingShelvesAPISpy(), cache: cache)

        let legacy = await service.shelves(for: .legacy)
        let multichain = await service.shelves(for: .multichain)

        XCTAssertEqual(legacy, legacySnapshot)
        XCTAssertEqual(multichain, multichainSnapshot)
    }
}

private extension TradingShelvesServiceEndpointSelectionTests {
    func makeService(
        api: TradingAPI,
        cache: InMemoryKeyedCache<TradingShelvesMode, TradingShelvesSnapshot> = .init()
    ) -> TradingShelvesServiceImplementation {
        TradingShelvesServiceImplementation(
            api: api,
            cache: cache,
            marketItemsCache: InMemoryKeyedCache<String, TradingMarketItem>(),
            requestContextProvider: TradingRequestContextProviderStub()
        )
    }

    func assertNetworkError(
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("Expected networkError", file: file, line: line)
        } catch let error as LoadShelvesFailure {
            guard case .networkError = error else {
                XCTFail("Expected networkError, got \(error)", file: file, line: line)
                return
            }
        } catch {
            XCTFail("Expected networkError, got \(error)", file: file, line: line)
        }
    }
}

private actor TradingShelvesAPISpy: TradingAPI {
    enum Call: Equatable {
        case getShelves
        case getShelvesV2
    }

    private var recordedCalls = [Call]()

    func calls() -> [Call] {
        recordedCalls
    }

    func getAssetChart(
        requestContext: TradingRequestContext,
        assetId: String,
        period: Period,
        currency: Currency
    ) async throws(TradingAPIError) -> [Coordinate] {
        throw .unknown(underlying: nil)
    }

    func getShelves(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponse {
        recordedCalls.append(.getShelves)
        throw .transportError(underlying: nil)
    }

    func getShelvesV2(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponseV2 {
        recordedCalls.append(.getShelvesV2)
        throw .transportError(underlying: nil)
    }

    func getAssetsCatalog(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        throw .unknown(underlying: nil)
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
        throw .unknown(underlying: nil)
    }

    func getAssets(
        requestContext: TradingRequestContext,
        ids: [String]
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        throw .unknown(underlying: nil)
    }

    func getAssetsDetailsV2(
        requestContext: TradingRequestContext,
        assetId: String
    ) async throws(TradingAPIError) -> Components.Schemas.AssetDetailsResponse {
        throw .unknown(underlying: nil)
    }
}

private struct TradingRequestContextProviderStub: TradingRequestContextProvider {
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
