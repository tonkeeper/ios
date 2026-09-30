@testable import KeeperCore
import TKTradingAPI
import XCTest

final class TradingAssetsListServiceEndpointSelectionTests: XCTestCase {
    func test_load_callsV1Endpoint() async {
        let api = TradingAssetsListAPISpy()
        let service = makeService(api: api)

        await assertNetworkError {
            _ = try await service.load(
                query: " ton ",
                category: .tokens
            )
        }
        let calls = await api.calls()

        XCTAssertEqual(
            calls,
            [
                .getAssetsCatalog(
                    tab: .tokens,
                    query: "ton",
                    cursor: nil,
                    pageSize: 30,
                    sourceShelf: nil
                ),
            ]
        )
    }
}

private extension TradingAssetsListServiceEndpointSelectionTests {
    func makeService(
        api: TradingAPI
    ) -> TradingAssetsListServiceImplementation {
        TradingAssetsListServiceImplementation(
            api: api,
            cache: InMemoryKeyedCache<TradingAssetsListServiceImplementation.QueryDescriptor, TradingAssetListSnapshot>(),
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
        } catch let error as TradingAssetsListServiceFailure {
            guard case .networkError = error else {
                XCTFail("Expected networkError, got \(error)", file: file, line: line)
                return
            }
        } catch {
            XCTFail("Expected networkError, got \(error)", file: file, line: line)
        }
    }
}

private actor TradingAssetsListAPISpy: TradingAPI {
    enum Call: Equatable {
        case getAssetsCatalog(
            tab: Components.Schemas.AssetsTab,
            query: String?,
            cursor: String?,
            pageSize: Int?,
            sourceShelf: String?
        )
        case getAssetsCatalogV2(
            tab: Components.Schemas.AssetsTab,
            query: String?,
            cursor: String?,
            pageSize: Int?,
            sourceShelf: String?
        )
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
        throw .unknown(underlying: nil)
    }

    func getShelvesV2(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponseV2 {
        throw .unknown(underlying: nil)
    }

    func getAssetsCatalog(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        recordedCalls.append(
            .getAssetsCatalog(
                tab: tab,
                query: query,
                cursor: cursor,
                pageSize: pageSize,
                sourceShelf: sourceShelf
            )
        )
        throw .transportError(underlying: nil)
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
        recordedCalls.append(
            .getAssetsCatalogV2(
                tab: tab,
                query: query,
                cursor: cursor,
                pageSize: pageSize,
                sourceShelf: sourceShelf
            )
        )
        throw .transportError(underlying: nil)
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
