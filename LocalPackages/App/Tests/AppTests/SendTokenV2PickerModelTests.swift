@testable import App
@testable import KeeperCore
import XCTest

final class SendTokenV2PickerModelTests: XCTestCase {
    func test_perpsCatalog_routesAllChainAndPerpetualsTabs() async throws {
        let catalog = CatalogSearchingSpy()
        catalog.page = TradingCatalogPage(
            rows: [
                .spot(makeSpot()),
                .perp(makeMarket(id: 7)),
            ],
            nextCursor: nil
        )
        let perps = PerpsSearchingSpy()
        perps.page = PerpsMarketsPage(items: [makeMarket(id: 2)], nextCursor: nil)
        let model = SendTokenV2PickerModel(
            multichainState: MultichainWalletState(
                walletId: "wallet",
                addresses: [.init(chain: .ton, address: "EQC")]
            ),
            displayMode: .includingMarketData,
            searchBehavior: .catalog,
            multichainService: PickerMultichainServiceStub(),
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: KeeperInfoRepositoryStub()
                )
            ),
            catalogSearching: catalog,
            perpsSearching: perps
        )

        XCTAssertEqual(model.initialState.filters, [.all, .chain(.ton), .perpetuals])

        let mixed = try await model.loadAssets(query: "eth", filter: .all, limit: 30, cursor: nil)
        XCTAssertEqual(catalog.requests.last?.showPerps, true)
        XCTAssertNil(catalog.requests.last?.chain)
        XCTAssertEqual(mixed.items.count, 2)

        _ = try await model.loadAssets(query: nil, filter: .chain(.ton), limit: 30, cursor: nil)
        XCTAssertEqual(catalog.requests.last?.showPerps, false)
        XCTAssertEqual(catalog.requests.last?.chain, "ton")

        let markets = try await model.loadAssets(query: "btc", filter: .perpetuals, limit: 30, cursor: nil)
        XCTAssertEqual(catalog.requests.count, 2)
        XCTAssertEqual(perps.requests, [.init(query: "btc", sort: .volume, cursor: nil)])
        XCTAssertEqual(markets.items, [.perp(makeMarket(id: 2))])
    }
}

private extension SendTokenV2PickerModelTests {
    func makeSpot() -> TradingCatalogSpot {
        TradingCatalogSpot(
            id: "ton/mainnet/coin",
            symbol: "TON",
            name: "Toncoin",
            imageURL: nil,
            decimals: 9,
            verification: .whitelist,
            price: "3.1",
            change24hPercent: "1.2",
            marketCap: "1000"
        )
    }

    func makeMarket(id: Int64) -> PerpsMarketSummary {
        PerpsMarketSummary(
            marketId: id,
            symbol: "ETH",
            name: "ETH",
            iconURL: nil,
            maxLeverage: 20,
            price: 1,
            priceChangePercent: 0,
            volume24h: 10
        )
    }
}

private final class CatalogSearchingSpy: TradingCatalogSearching, @unchecked Sendable {
    struct Request: Equatable {
        let chain: String?
        let showPerps: Bool
    }

    var page = TradingCatalogPage(rows: [], nextCursor: nil)
    private(set) var requests = [Request]()

    func catalogSearch(
        query _: String?,
        chain: String?,
        showPerps: Bool,
        sort _: MultichainAssetSearchSort,
        cursor _: String?,
        pageSize _: Int
    ) async throws -> TradingCatalogPage {
        requests.append(Request(chain: chain, showPerps: showPerps))
        return page
    }
}

private final class PerpsSearchingSpy: PerpsMarketsSearching, @unchecked Sendable {
    struct Request: Equatable {
        let query: String?
        let sort: PerpsMarketsSort
        let cursor: String?
    }

    var page = PerpsMarketsPage(items: [], nextCursor: nil)
    private(set) var requests = [Request]()

    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage {
        requests.append(.init(query: query, sort: sort, cursor: cursor))
        return page
    }
}

private final class PickerMultichainServiceStub: MultichainService, @unchecked Sendable {
    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        ([], nil)
    }

    func getWalletAssets(
        state _: MultichainWalletState,
        currencies _: [String],
        assetIds _: [String]?,
        capabilities _: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden _: Bool?,
        hideDust _: Bool?,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        MultichainWalletAssetsPage(assets: [], nextCursor: nil, fiatPrice: [:])
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .apiError(message: "Unimplemented")
    }

    func getWallet(walletId _: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        throw .apiError(message: "Unimplemented")
    }

    func saveWalletAssetsFilters(walletId _: String, changes _: [MultichainAssetFilterChange]) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletActivities(
        state _: MultichainWalletState,
        limit _: Int?,
        cursor _: String?,
        chain _: MultichainChain?,
        assetId _: String?,
        activityTypeFilter _: MultichainActivityTypeFilter?,
        showPerps _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        throw .apiError(message: "Unimplemented")
    }

    func broadcastTx(chain _: MultichainChain, signedTransaction _: Data) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        throw .apiError(message: "Unimplemented")
    }

    func getFees(chain _: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle] {
        throw .apiError(message: "Unimplemented")
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }
}

private final class KeeperInfoRepositoryStub: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        throw Error.noKeeperInfo
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
