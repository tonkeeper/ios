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
            state: MultichainWalletState(walletId: "wallet", addresses: []),
            limit: 30,
            cursor: nil,
            assetId: usdt,
            activityTypeFilter: nil,
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
            state: MultichainWalletState(walletId: "wallet", addresses: []),
            limit: 10,
            cursor: "c1",
            assetId: "eth/mainnet/erc20/usdt",
            activityTypeFilter: .send,
            hideDust: nil
        )

        XCTAssertEqual(api.lastAssetId, "eth/mainnet/erc20/usdt")
        XCTAssertNil(api.lastChain)
        XCTAssertEqual(api.lastActivityTypeFilter, .send)
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
            state: MultichainWalletState(walletId: "wallet", addresses: []),
            limit: 10,
            cursor: nil,
            chain: .eth,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        XCTAssertEqual(api.lastChain, .eth)
        XCTAssertNil(api.lastAssetId)
    }

    func test_getWalletActivities_dropsActivitiesOfTheSiblingTonAccount() async throws {
        let service = makeService(page: MultichainWalletActivitiesPage(
            activities: [
                makeActivity(id: "own", assetId: Self.tonAssetId, walletAddress: Self.ownRawAddress),
                makeActivity(id: "sibling", assetId: Self.tonAssetId, walletAddress: Self.siblingRawAddress),
            ],
            nextCursor: nil
        ))

        let result = try await service.getWalletActivities(
            state: makeState(tonAddress: Self.ownFriendlyAddress),
            limit: 30,
            cursor: nil,
            chain: .ton,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        XCTAssertEqual(result.activities.map(\.txIds), [["own"]])
    }

    func test_getWalletActivities_matchesOwnAccountAcrossAddressForms() async throws {
        let service = makeService(page: MultichainWalletActivitiesPage(
            activities: [
                makeActivity(id: "raw", assetId: Self.tonAssetId, walletAddress: Self.ownRawAddress),
                makeActivity(id: "bounceable", assetId: Self.tonAssetId, walletAddress: Self.ownBounceableAddress),
            ],
            nextCursor: nil
        ))

        let result = try await service.getWalletActivities(
            state: makeState(tonAddress: Self.ownFriendlyAddress),
            limit: 30,
            cursor: nil,
            chain: .ton,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        XCTAssertEqual(result.activities.map(\.txIds), [["raw"], ["bounceable"]])
    }

    func test_getWalletActivities_keepsActivitiesThatNameNoTonAccount() async throws {
        let service = makeService(page: MultichainWalletActivitiesPage(
            activities: [
                makeActivity(id: "evm", assetId: "eth/mainnet/coin", walletAddress: "0xwallet"),
                makeActivity(id: "unknown", assetId: "eth/mainnet/coin", walletAddress: nil),
            ],
            nextCursor: nil
        ))

        let result = try await service.getWalletActivities(
            state: makeState(tonAddress: Self.ownFriendlyAddress),
            limit: 30,
            cursor: nil,
            chain: nil,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        XCTAssertEqual(result.activities.map(\.txIds), [["evm"], ["unknown"]])
    }

    func test_getWalletActivities_keepsEverythingWhenTheWalletHasNoTonAccount() async throws {
        let service = makeService(page: MultichainWalletActivitiesPage(
            activities: [
                makeActivity(id: "own", assetId: Self.tonAssetId, walletAddress: Self.ownRawAddress),
                makeActivity(id: "sibling", assetId: Self.tonAssetId, walletAddress: Self.siblingRawAddress),
            ],
            nextCursor: nil
        ))

        let result = try await service.getWalletActivities(
            state: MultichainWalletState(walletId: "wallet", addresses: []),
            limit: 30,
            cursor: nil,
            chain: .ton,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        XCTAssertEqual(result.activities.map(\.txIds), [["own"], ["sibling"]])
    }

    func test_getWalletActivities_keepsTheBackendCursorWhenEveryActivityIsFilteredOut() async throws {
        let service = makeService(page: MultichainWalletActivitiesPage(
            activities: [makeActivity(id: "sibling", assetId: Self.tonAssetId, walletAddress: Self.siblingRawAddress)],
            nextCursor: "next"
        ))

        let result = try await service.getWalletActivities(
            state: makeState(tonAddress: Self.ownFriendlyAddress),
            limit: 30,
            cursor: nil,
            chain: .ton,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        XCTAssertTrue(result.activities.isEmpty)
        XCTAssertEqual(result.nextCursor, "next")
    }
}

private extension MultichainServiceAssetActivitiesFilterTests {
    static let tonAssetId = "ton/mainnet/coin"
    static let ownFriendlyAddress = "UQDjcVuq603VRoJJBLScazVm04HHMWwpd8dmYsHN4JeROjRZ"
    static let ownBounceableAddress = "EQDjcVuq603VRoJJBLScazVm04HHMWwpd8dmYsHN4JeROmmc"
    static let ownRawAddress = "0:e3715baaeb4dd546824904b49c6b3566d381c7316c2977c76662c1cde097913a"
    static let siblingRawAddress = "0:9d0df57ab7784ed294e9fd4586cda284b63b72efb0902a9c1fe1ac8b6c7a19e9"

    func makeService(page: MultichainWalletActivitiesPage) -> MultichainServiceImplementation {
        MultichainServiceImplementation(
            multichainClientAPI: MultichainAssetActivitiesClientAPIStub(page: page),
            visibilityChangesController: makeVisibilityChangesController(),
            pendingTransactionsService: NoopPendingTransactionsService()
        )
    }

    func makeState(tonAddress: String) -> MultichainWalletState {
        MultichainWalletState(
            walletId: "wallet",
            addresses: [
                MultichainWalletAddress(chain: .ton, address: tonAddress, type: .tonV5R1),
                MultichainWalletAddress(chain: .eth, address: "0xwallet"),
            ]
        )
    }

    func makeActivity(
        id: String,
        assetId: String,
        walletAddress: String? = "0x1"
    ) -> MultichainActivity {
        MultichainActivity(
            activityType: .send,
            status: .confirmed,
            blockTime: Date(timeIntervalSince1970: 1),
            blockNumber: 1,
            fromChain: .eth,
            toChain: .eth,
            walletAddress: walletAddress,
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
    private(set) var lastActivityTypeFilter: MultichainActivityTypeFilter?
    private(set) var lastShowPerps: Bool?

    init(page: MultichainWalletActivitiesPage) {
        self.page = page
    }

    func getWalletActivities(
        walletId _: String,
        limit: Int?,
        cursor: String?,
        chain: MultichainChain?,
        assetId: String?,
        activityTypeFilter: MultichainActivityTypeFilter?,
        showPerps: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainClientAPIError) -> MultichainWalletActivitiesPage {
        lastLimit = limit
        lastCursor = cursor
        lastChain = chain
        lastAssetId = assetId
        lastActivityTypeFilter = activityTypeFilter
        lastShowPerps = showPerps
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
