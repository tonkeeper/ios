@testable import App
@preconcurrency import BigInt
import Foundation
@testable import KeeperCore
import XCTest

final class MultichainSwapTokenPickerModelTests: XCTestCase {
    func test_sourcePickerRequestsOnlySwapCapableWalletAssets() async throws {
        let asset = MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "ton/mainnet/coin",
                name: "Toncoin",
                symbol: "TON",
                decimals: 9,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: 1
        )
        let multichainService = PickerMultichainServiceSpy(
            walletAssetsResult: .success(
                MultichainWalletAssetsPage(assets: [asset], nextCursor: nil, fiatPrice: [:])
            )
        )
        let model = MultichainSwapTokenPickerModel(
            side: .source,
            multichainState: MultichainWalletState(
                walletId: "wallet",
                addresses: [.init(chain: .ton, address: "tonwallet")]
            ),
            selectedAsset: nil,
            multichainService: multichainService,
            multichainSwapService: PickerSwapServiceStub(),
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: KeeperInfoRepositoryStub()
                )
            )
        )

        let result = try await model.loadAssets(query: nil, filter: .all, limit: 10, cursor: nil)

        let requests = await multichainService.walletAssetsRequests()
        XCTAssertEqual(requests.map(\.capabilities), [[.swap]])
        XCTAssertEqual(result.assets.map(\.asset.assetId), ["ton/mainnet/coin"])
    }
}

private actor PickerMultichainServiceSpy: MultichainService {
    struct WalletAssetsRequest {
        let capabilities: [MultichainAssetCapability]?
        let availableOnly: Bool?
        let showHidden: Bool?
    }

    private let walletAssetsResult: Result<MultichainWalletAssetsPage, MultichainServiceError>
    private var recordedWalletAssetsRequests = [WalletAssetsRequest]()

    init(walletAssetsResult: Result<MultichainWalletAssetsPage, MultichainServiceError>) {
        self.walletAssetsResult = walletAssetsResult
    }

    func walletAssetsRequests() -> [WalletAssetsRequest] {
        recordedWalletAssetsRequests
    }

    func getWalletAssets(
        state _: MultichainWalletState,
        currencies _: [String],
        assetIds _: [String]?,
        capabilities: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust _: Bool?,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        recordedWalletAssetsRequests.append(
            WalletAssetsRequest(
                capabilities: capabilities,
                availableOnly: availableOnly,
                showHidden: showHidden
            )
        )
        return try walletAssetsResult.get()
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .apiError(message: "Unimplemented")
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
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

    func registerWallet(walletId _: String, addresses _: [MultichainWalletAddress]) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
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

private struct PickerSwapServiceStub: MultichainSwapService {
    enum Error: Swift.Error {
        case unimplemented
    }

    func listCrossSwapAssets(query _: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset] {
        throw Error.unimplemented
    }

    func getCrossSwapAsset(assetId _: String) async throws -> MultichainSwapAsset {
        throw Error.unimplemented
    }

    func getCrossSwapConfig(
        walletId _: String,
        fromAssetId _: String?,
        toAssetId _: String?
    ) async throws -> MultichainSwapConfig {
        throw Error.unimplemented
    }

    func createCrossSwapQuote(
        request _: MultichainSwapQuoteRequest,
        walletId _: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        throw .unknown(statusCode: 0)
    }

    func prepareCrossSwapRoute(
        routeId _: String,
        request _: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws -> MultichainSwapPrepare {
        throw Error.unimplemented
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
