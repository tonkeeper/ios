@testable import KeeperCore
import TKTradingAPI
import XCTest

final class TradingAssetDetailsServiceEndpointSelectionTests: XCTestCase {
    func test_loadAssetDetails_whenMultichainDisabled_callsV1Endpoint() async {
        let api = TradingAPISpy()
        let service = makeService(
            api: api,
            isMultichainEnabled: false
        )

        await assertNetworkError {
            _ = try await service.loadAssetDetails(id: "ton/mainnet/jetton/0:asset")
        }
        let calls = await api.calls()

        XCTAssertEqual(
            calls,
            [
                .getAssetsDetails(assetId: "ton/mainnet/jetton/0:asset"),
            ]
        )
    }

    func test_loadAssetDetails_whenMultichainEnabled_callsV2Endpoint() async {
        let api = TradingAPISpy()
        let service = makeService(
            api: api,
            isMultichainEnabled: true
        )

        await assertNetworkError {
            _ = try await service.loadAssetDetails(id: "ton/mainnet/jetton/0:asset")
        }
        let calls = await api.calls()

        XCTAssertEqual(
            calls,
            [
                .getAssetsDetailsV2(assetId: "ton/mainnet/jetton/0:asset"),
            ]
        )
    }
}

private extension TradingAssetDetailsServiceEndpointSelectionTests {
    func makeService(
        api: TradingAPI,
        isMultichainEnabled: Bool
    ) -> TradingAssetDetailsServiceImplementation {
        TradingAssetDetailsServiceImplementation(
            api: api,
            cache: InMemoryKeyedCache<String, TradingAssetDetails>(),
            requestContextProvider: TradingRequestContextProviderStub(),
            isMultichainEnabled: isMultichainEnabled
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
        } catch let error as TradingAssetDetailsServiceFailure {
            guard case .networkError = error else {
                XCTFail("Expected networkError, got \(error)", file: file, line: line)
                return
            }
        } catch {
            XCTFail("Expected networkError, got \(error)", file: file, line: line)
        }
    }
}

private actor TradingAPISpy: TradingAPI {
    enum Call: Equatable {
        case getAssetsDetails(assetId: String)
        case getAssetsDetailsV2(assetId: String)
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
        sourceShelf: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        throw .unknown(underlying: nil)
    }

    func getAssets(
        requestContext: TradingRequestContext,
        ids: [String]
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        throw .unknown(underlying: nil)
    }

    func getAssetsDetails(
        requestContext: TradingRequestContext,
        assetId: String
    ) async throws(TradingAPIError) -> Components.Schemas.AssetDetailsResponse {
        recordedCalls.append(.getAssetsDetails(assetId: assetId))
        throw .transportError(underlying: nil)
    }

    func getAssetsDetailsV2(
        requestContext: TradingRequestContext,
        assetId: String
    ) async throws(TradingAPIError) -> Components.Schemas.AssetDetailsResponse {
        recordedCalls.append(.getAssetsDetailsV2(assetId: assetId))
        throw .transportError(underlying: nil)
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
