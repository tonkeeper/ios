import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class MultichainServiceAssetActivitiesFilterTests: XCTestCase {
    func test_getWalletActivitiesByAssetId_returnsBackendPageAsIs() async throws {
        let usdt = "eth/mainnet/erc20/usdt"
        let eth = "eth/mainnet/coin"
        let page = MultichainWalletActivitiesPage(
            activities: [
                makeActivity(id: "a1", assetId: usdt),
                makeActivity(id: "a2", assetId: eth),
            ],
            nextCursor: "next"
        )
        let service = MultichainServiceImplementation(
            multichainClientAPI: MultichainAssetActivitiesClientAPIStub(page: page),
            visibilityChangesController: makeVisibilityChangesController(),
            pendingTransactionsService: NoopPendingTransactionsService()
        )

        let result = try await service.getWalletActivities(
            walletId: "wallet",
            limit: 30,
            cursor: nil,
            assetId: usdt,
            activityType: nil,
            hideDust: nil
        )

        XCTAssertEqual(result.activities.map(\.txIds), [["a1"], ["a2"]])
        XCTAssertEqual(result.nextCursor, "next")
    }

    func test_getWalletActivitiesByAssetId_filtersByAssetIdInsteadOfChain() async throws {
        let api = MultichainAssetActivitiesClientAPIStub(
            page: MultichainWalletActivitiesPage(activities: [], nextCursor: nil)
        )
        let service = MultichainServiceImplementation(
            multichainClientAPI: api,
            visibilityChangesController: makeVisibilityChangesController(),
            pendingTransactionsService: NoopPendingTransactionsService()
        )

        _ = try await service.getWalletActivities(
            walletId: "wallet",
            limit: 10,
            cursor: "c1",
            assetId: "eth/mainnet/erc20/usdt",
            activityType: .send,
            hideDust: nil
        )

        XCTAssertEqual(api.lastAssetId, "eth/mainnet/erc20/usdt")
        XCTAssertNil(api.lastChain)
        XCTAssertEqual(api.lastActivityType, .send)
        XCTAssertEqual(api.lastLimit, 10)
        XCTAssertEqual(api.lastCursor, "c1")
    }

    func test_getWalletActivitiesByChain_doesNotSendAssetId() async throws {
        let api = MultichainAssetActivitiesClientAPIStub(
            page: MultichainWalletActivitiesPage(activities: [], nextCursor: nil)
        )
        let service = MultichainServiceImplementation(
            multichainClientAPI: api,
            visibilityChangesController: makeVisibilityChangesController(),
            pendingTransactionsService: NoopPendingTransactionsService()
        )

        _ = try await service.getWalletActivities(
            walletId: "wallet",
            limit: 10,
            cursor: nil,
            chain: .eth,
            assetId: nil,
            activityType: nil,
            hideDust: nil
        )

        XCTAssertEqual(api.lastChain, .eth)
        XCTAssertNil(api.lastAssetId)
    }
}

private extension MultichainServiceAssetActivitiesFilterTests {
    func makeActivity(id: String, assetId: String) -> MultichainActivity {
        MultichainActivity(
            activityType: .send,
            status: .confirmed,
            blockTime: Date(timeIntervalSince1970: 1),
            blockNumber: 1,
            fromChain: .eth,
            toChain: .eth,
            walletAddress: "0x1",
            direction: .outgoing,
            fromAddress: "0x1",
            toAddress: "0x2",
            outToken: MultichainAssetDetails(
                assetId: assetId,
                name: "Token",
                symbol: "TKN",
                decimals: 18,
                image: ""
            ),
            outAmount: "1",
            outAmountUsd: 1,
            inToken: nil,
            inAmount: nil,
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: [id],
            isRead: nil,
            isSpam: false
        )
    }

    func makeVisibilityChangesController() -> VisibilityChangesController {
        let storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        return VisibilityChangesController(
            vault: FileSystemVault(fileManager: .default, directory: storageDirectory),
            writer: MultichainAssetActivitiesVisibilityChangesWriterStub()
        )
    }
}

private struct NoopPendingTransactionsService: PendingTransactionsService {
    func report(_: MultichainPendingTransaction) async {}
    func flushRetained() async {}
}

private struct MultichainAssetActivitiesVisibilityChangesWriterStub: MultichainAssetVisibilityChangesWriter {
    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {}
}

private final class MultichainAssetActivitiesClientAPIStub: MultichainClientAPI {
    private let page: MultichainWalletActivitiesPage
    private(set) var lastLimit: Int?
    private(set) var lastCursor: String?
    private(set) var lastChain: MultichainChain?
    private(set) var lastAssetId: String?
    private(set) var lastActivityType: MultichainActivityType?

    init(page: MultichainWalletActivitiesPage) {
        self.page = page
    }

    func getWalletActivities(
        walletId _: String,
        limit: Int?,
        cursor: String?,
        chain: MultichainChain?,
        assetId: String?,
        activityType: MultichainActivityType?,
        hideDust _: Bool?
    ) async throws(MultichainClientAPIError) -> MultichainWalletActivitiesPage {
        lastLimit = limit
        lastCursor = cursor
        lastChain = chain
        lastAssetId = assetId
        lastActivityType = activityType
        return page
    }

    func healthcheck() async throws(MultichainClientAPIError) -> MultichainHealth {
        throw .connectionError(underlying: nil)
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainClientAPIError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .connectionError(underlying: nil)
    }

    func getWallet(walletId _: String) async throws(MultichainClientAPIError) -> MultichainRegisteredWallet {
        throw .connectionError(underlying: nil)
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainClientAPIError) -> MultichainWalletSyncStatus {
        throw .connectionError(underlying: nil)
    }

    func getWalletAssets(
        walletId _: String,
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
    ) async throws(MultichainClientAPIError) -> MultichainWalletAssetRecordsPage {
        throw .connectionError(underlying: nil)
    }

    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func getWalletChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        throw .connectionError(underlying: nil)
    }

    func broadcastTx(
        chain _: MultichainChain,
        signedTransaction _: Data
    ) async throws(MultichainClientAPIError) -> MultichainBroadcastResult {
        throw .connectionError(underlying: nil)
    }

    func addPendingTransaction(_: MultichainPendingTransaction) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func getFees(chain _: MultichainChain) async throws(MultichainClientAPIError) -> MultichainFeeEstimate {
        throw .connectionError(underlying: nil)
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainClientAPIError) -> [MultichainRaffle] {
        throw .connectionError(underlying: nil)
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func getRealtimeConnectionToken() async throws(MultichainClientAPIError) -> String {
        throw .connectionError(underlying: nil)
    }

    func getWalletRealtimeToken(walletId _: String) async throws(MultichainClientAPIError) -> String {
        throw .connectionError(underlying: nil)
    }
}
