@testable import KeeperCore
import TKFeatureFlags
import TKTradingAPI
import XCTest

final class ChartServiceTests: XCTestCase {
    override func tearDown() {
        ChartURLProtocolStub.handler = nil
        super.tearDown()
    }

    func test_loadChartData_whenMultichainResponseIsEmpty_throwsBadResponseAndDoesNotSave() async {
        let repository = ChartDataRepositorySpy()
        let service = makeService(
            tradingAPI: TradingAPIStub(result: .success([])),
            repository: repository
        )

        await assertThrowsChartServiceError(.badResponse) {
            _ = try await service.loadChartData(
                period: .month,
                asset: .multichain(assetId: "ton/mainnet/coin"),
                currency: .USD,
                network: .mainnet
            )
        }
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func test_loadChartData_whenLegacyResponseIsEmpty_throwsBadResponseAndDoesNotSave() async throws {
        let repository = ChartDataRepositorySpy()
        let service = try makeLegacyService(
            responseBody: XCTUnwrap(#"{"points":[]}"#.data(using: .utf8)),
            repository: repository
        )

        await assertThrowsChartServiceError(.badResponse) {
            _ = try await service.loadChartData(
                period: .month,
                asset: .legacy(token: "TON"),
                currency: .USD,
                network: .mainnet
            )
        }
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func test_loadChartData_whenLegacyURLIsInvalid_throwsNetworkErrorAndDoesNotSave() async throws {
        let repository = ChartDataRepositorySpy()
        let service = try makeLegacyService(
            responseBody: Data(),
            repository: repository,
            tonapiV2Endpoint: "http://%"
        )

        await assertThrowsChartServiceError(.networkError) {
            _ = try await service.loadChartData(
                period: .month,
                asset: .legacy(token: "TON"),
                currency: .USD,
                network: .mainnet
            )
        }
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func test_loadChartData_whenMultichainResponseHasCoordinates_returnsAndSavesCoordinates() async throws {
        let coordinates = [
            Coordinate(x: 1, y: 10),
            Coordinate(x: 2, y: 20),
        ]
        let repository = ChartDataRepositorySpy()
        let service = makeService(
            tradingAPI: TradingAPIStub(result: .success(coordinates)),
            repository: repository
        )

        let loadedCoordinates = try await service.loadChartData(
            period: .month,
            asset: .multichain(assetId: "ton/mainnet/coin"),
            currency: .USD,
            network: .mainnet
        )

        XCTAssertEqual(loadedCoordinates.map(\.x), coordinates.map(\.x))
        XCTAssertEqual(loadedCoordinates.map(\.y), coordinates.map(\.y))
        XCTAssertEqual(repository.savedCoordinates?.map(\.x), coordinates.map(\.x))
        XCTAssertEqual(repository.savedCoordinates?.map(\.y), coordinates.map(\.y))
    }

    func test_loadChartData_whenLegacyResponseHasCoordinates_returnsAndSavesCoordinates() async throws {
        let expectedCoordinates = [
            Coordinate(x: 1, y: 10),
            Coordinate(x: 2, y: 20),
        ]
        let repository = ChartDataRepositorySpy()
        let service = try makeLegacyService(
            responseBody: XCTUnwrap(#"{"points":[[2,20],[1,10]]}"#.data(using: .utf8)),
            repository: repository
        )

        let loadedCoordinates = try await service.loadChartData(
            period: .month,
            asset: .legacy(token: "TON"),
            currency: .USD,
            network: .mainnet
        )

        XCTAssertEqual(loadedCoordinates.map(\.x), expectedCoordinates.map(\.x))
        XCTAssertEqual(loadedCoordinates.map(\.y), expectedCoordinates.map(\.y))
        XCTAssertEqual(repository.savedCoordinates?.map(\.x), expectedCoordinates.map(\.x))
        XCTAssertEqual(repository.savedCoordinates?.map(\.y), expectedCoordinates.map(\.y))
    }

    func test_getChartData_whenCachedDataMissingOrEmpty_returnsNil() throws {
        let repository = SessionChartDataRepository()
        let asset = ChartAsset.multichain(assetId: "ton/mainnet/jetton/\(UUID().uuidString)")
        let service = makeService(
            tradingAPI: TradingAPIStub(result: .success([])),
            repository: repository
        )

        XCTAssertNil(
            service.getChartData(
                period: .month,
                asset: asset,
                currency: .USD,
                network: .mainnet
            )
        )

        try repository.saveChartData(
            coordinates: [],
            period: .month,
            token: asset.cacheToken,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertNil(
            service.getChartData(
                period: .month,
                asset: asset,
                currency: .USD,
                network: .mainnet
            )
        )
    }

    func test_getChartData_whenSameIdentifierCachedInOtherMode_doesNotReturnForeignData() throws {
        let repository = SessionChartDataRepository()
        let identifier = "identifier-\(UUID().uuidString)"
        let service = makeService(
            tradingAPI: TradingAPIStub(result: .success([])),
            repository: repository
        )

        try repository.saveChartData(
            coordinates: [Coordinate(x: 1, y: 10)],
            period: .month,
            token: ChartAsset.legacy(token: identifier).cacheToken,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertNil(
            service.getChartData(
                period: .month,
                asset: .multichain(assetId: identifier),
                currency: .USD,
                network: .mainnet
            )
        )
        XCTAssertEqual(
            service.getChartData(
                period: .month,
                asset: .legacy(token: identifier),
                currency: .USD,
                network: .mainnet
            )?.map(\.y),
            [10]
        )
    }

    func test_loadChartData_savesUnderModeScopedCacheToken() async throws {
        let repository = ChartDataRepositorySpy()
        let asset = ChartAsset.multichain(assetId: "ton/mainnet/coin")
        let service = makeService(
            tradingAPI: TradingAPIStub(result: .success([Coordinate(x: 1, y: 10)])),
            repository: repository
        )

        _ = try await service.loadChartData(
            period: .month,
            asset: asset,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertEqual(repository.savedToken, asset.cacheToken)
    }
}

private extension ChartServiceTests {
    func makeService(
        tradingAPI: TradingAPI,
        repository: ChartDataRepository
    ) -> ChartServiceImplementation {
        ChartServiceImplementation(
            apiProvider: APIProvider { _ in
                fatalError("Legacy API should not be used")
            },
            tradingAPI: tradingAPI,
            tradingRequestContextProvider: TradingRequestContextProviderStub(),
            repository: repository
        )
    }

    func makeLegacyService(
        responseBody: Data,
        repository: ChartDataRepository,
        tonapiV2Endpoint: String = "https://example.com"
    ) throws -> ChartServiceImplementation {
        ChartURLProtocolStub.handler = { request in
            let response = try HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return try (XCTUnwrap(response), responseBody)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChartURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let api = API(
            hostProvider: APIHostProviderStub(),
            urlSession: session,
            configuration: makeConfiguration(tonapiV2Endpoint: tonapiV2Endpoint),
            requestCreationQueue: DispatchQueue(label: "ChartServiceTests.API")
        )

        return ChartServiceImplementation(
            apiProvider: APIProvider { _ in api },
            tradingAPI: TradingAPIStub(result: .failure(.unknown(underlying: nil))),
            tradingRequestContextProvider: TradingRequestContextProviderStub(),
            repository: repository
        )
    }

    func assertThrowsChartServiceError(
        _ expectedError: ChartServiceError,
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("Expected \(expectedError)", file: file, line: line)
        } catch let error as ChartServiceError {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected \(expectedError), got \(error)", file: file, line: line)
        }
    }

    func makeConfiguration(tonapiV2Endpoint: String) -> Configuration {
        let configuration = BootConfiguration.empty
        let bootConfiguration = BootConfiguration(
            tonapiV2Endpoint: tonapiV2Endpoint,
            tonapiTestnetHost: configuration.tonapiTestnetHost,
            tonAPISSEEndpointV2: configuration.tonAPISSEEndpointV2,
            batteryHost: configuration.batteryHost,
            tonApiV2Key: configuration.tonApiV2Key,
            tonConnectBridge: configuration.tonConnectBridge,
            mercuryoSecret: configuration.mercuryoSecret,
            supportLink: configuration.supportLink,
            directSupportUrl: configuration.directSupportUrl,
            tonkeeperNewsUrl: configuration.tonkeeperNewsUrl,
            stonfiUrl: configuration.stonfiUrl,
            webSwapsUrl: configuration.webSwapsUrl,
            faqUrl: configuration.faqUrl,
            stakingInfoUrl: configuration.stakingInfoUrl,
            isBatteryBeta: configuration.isBatteryBeta,
            accountExplorer: configuration.accountExplorer,
            transactionExplorer: configuration.transactionExplorer,
            nftOnExplorerUrl: configuration.nftOnExplorerUrl,
            batteryMeanFees: configuration.batteryMeanFees,
            batteryReservedAmount: configuration.batteryReservedAmount,
            batteryMeanPriceSwap: configuration.batteryMeanPriceSwap,
            batteryMeanPriceJetton: configuration.batteryMeanPriceJetton,
            batteryMeanPriceNFT: configuration.batteryMeanPriceNFT,
            batteryMeanPriceTRCMin: configuration.batteryMeanPriceTRCMin,
            batteryMeanPriceTRCMax: configuration.batteryMeanPriceTRCMax,
            batteryMaxInputAmount: configuration.batteryMaxInputAmount,
            batteryRefundEndpoint: configuration.batteryRefundEndpoint,
            disableBattery: configuration.disableBattery,
            disableBatterySend: configuration.disableBatterySend,
            disableBatteryCryptoRechargeModule: configuration.disableBatteryCryptoRechargeModule,
            scamApiURL: configuration.scamApiURL,
            flags: configuration.flags,
            stories: configuration.stories,
            reportAmount: configuration.reportAmount,
            stakingEnabledProviders: configuration.stakingEnabledProviders,
            qrScannerExtensions: configuration.qrScannerExtensions,
            region: configuration.region,
            tronApiUrl: configuration.tronApiUrl,
            tronSwapUrl: configuration.tronSwapUrl,
            tronSwapTitle: configuration.tronSwapTitle,
            tonkeeperApiUrl: configuration.tonkeeperApiUrl,
            aptabaseEndpoint: configuration.aptabaseEndpoint,
            multichainHelpUrl: configuration.multichainHelpUrl,
            multichain: configuration.multichain,
            trading: configuration.trading,
            explorers: configuration.explorers
        )
        return Configuration(
            bootConfigurationService: BootConfigurationServiceStub(
                bootConfigurations: BootConfigurations(
                    mainnet: bootConfiguration,
                    testnet: .empty
                )
            ),
            featureFlags: FeatureFlagsStub(),
            tkAppSettings: AppSettingsStub()
        )
    }
}

private final class ChartDataRepositorySpy: ChartDataRepository {
    private(set) var savedCoordinates: [Coordinate]?
    private(set) var savedToken: String?
    private(set) var saveCallCount = 0
    var chartData: [Coordinate]?

    func getChartData(
        period: Period,
        token: String,
        currency: Currency,
        network: Network
    ) -> [Coordinate]? {
        chartData
    }

    func saveChartData(
        coordinates: [Coordinate],
        period: Period,
        token: String,
        currency: Currency,
        network: Network
    ) throws {
        saveCallCount += 1
        savedCoordinates = coordinates
        savedToken = token
    }
}

private final class TradingAPIStub: TradingAPI {
    private let result: Result<[Coordinate], TradingAPIError>

    init(result: Result<[Coordinate], TradingAPIError>) {
        self.result = result
    }

    func getAssetChart(
        requestContext: TradingRequestContext,
        assetId: String,
        period: Period,
        currency: Currency
    ) async throws(TradingAPIError) -> [Coordinate] {
        switch result {
        case let .success(coordinates):
            return coordinates
        case let .failure(error):
            throw error
        }
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

private struct APIHostProviderStub: APIHostProvider {
    var basePath: String {
        get async {
            "https://example.com"
        }
    }
}

private struct BootConfigurationServiceStub: BootConfigurationService {
    let bootConfigurations: BootConfigurations

    func getConfiguration() throws -> BootConfigurations {
        bootConfigurations
    }

    func loadConfiguration() async throws -> BootConfigurations {
        bootConfigurations
    }
}

private final class FeatureFlagsStub: TKFeatureFlags {
    var allValues: [FeatureFlag: FeatureFlagValue] = [:]

    subscript(flag: FeatureFlag) -> Bool {
        get { false }
        set {}
    }

    func devOverride(for flag: FeatureFlag) -> Bool? {
        nil
    }

    func resetValue(for flag: FeatureFlag) {}

    func loadRemoteConfig() async {}
}

private final class AppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
    var raffleDebugNow: Date?
}

private final class ChartURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
