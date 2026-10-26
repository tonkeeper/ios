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
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
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
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: KeeperInfoRepositoryStub()
                )
            )
        )

        let result = try await model.loadAssets(query: nil, filter: .all, limit: 10, cursor: nil)

        let requests = await multichainService.walletAssetsRequests()
        XCTAssertEqual(requests.map(\.capabilities), [[.swap]])
        XCTAssertEqual(requests.map(\.availableOnly), [true])
        XCTAssertEqual(requests.map(\.showHidden), [false])
        XCTAssertEqual(requests.map(\.showAll), [nil])
        XCTAssertEqual(requests.map(\.hideDust), [false])
        XCTAssertEqual(result.assets.map(\.asset.assetId), ["ton/mainnet/coin"])
    }

    func test_receivePickerRequestsSwapCapableWalletAssetsAndExcludesSource() async throws {
        let source = makeAsset(assetId: "ton/mainnet/coin", symbol: "TON")
        let destination = makeAsset(assetId: "sol/mainnet/coin", symbol: "SOL")
        let multichainService = PickerMultichainServiceSpy(
            walletAssetsResult: .success(
                MultichainWalletAssetsPage(assets: [source, destination], nextCursor: "next", fiatPrice: [:])
            )
        )
        let model = MultichainSwapTokenPickerModel(
            side: .receive(sourceAssetId: source.asset.assetId),
            multichainState: MultichainWalletState(
                walletId: "wallet",
                addresses: [.init(chain: .ton, address: "tonwallet")]
            ),
            selectedAsset: nil,
            multichainService: multichainService,
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: KeeperInfoRepositoryStub()
                )
            )
        )

        let result = try await model.loadAssets(query: nil, filter: .all, limit: 10, cursor: nil)
        let nextPage = try await model.loadAssets(query: nil, filter: .all, limit: 10, cursor: result.nextCursor)

        let requests = await multichainService.walletAssetsRequests()
        XCTAssertEqual(requests.map(\.capabilities), [[.swap], [.swap]])
        XCTAssertEqual(requests.map(\.availableOnly), [false, false])
        XCTAssertEqual(requests.map(\.showHidden), [true, true])
        XCTAssertEqual(requests.map(\.showAll), [true, true])
        XCTAssertEqual(requests.map(\.hideDust), [false, false])
        XCTAssertEqual(requests.map(\.cursor), [nil, "next"])
        XCTAssertEqual(result.assets.map(\.asset.assetId), [destination.asset.assetId])
        XCTAssertEqual(result.nextCursor, "next")
        XCTAssertEqual(nextPage.assets.map(\.asset.assetId), [destination.asset.assetId])
    }

    private func makeAsset(assetId: String, symbol: String) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: symbol,
                symbol: symbol,
                decimals: 9,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 1
        )
    }
}

private actor PickerMultichainServiceSpy: MultichainService {
    struct WalletAssetsRequest {
        let capabilities: [MultichainAssetCapability]?
        let availableOnly: Bool?
        let showHidden: Bool?
        let showAll: Bool?
        let hideDust: Bool?
        let cursor: String?
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
        showAll: Bool?,
        hideDust: Bool?,
        limit _: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        recordedWalletAssetsRequests.append(
            WalletAssetsRequest(
                capabilities: capabilities,
                availableOnly: availableOnly,
                showHidden: showHidden,
                showAll: showAll,
                hideDust: hideDust,
                cursor: cursor
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
        market _: Int?,
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
