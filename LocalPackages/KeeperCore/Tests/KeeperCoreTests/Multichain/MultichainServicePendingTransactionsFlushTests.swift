import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class MultichainServicePendingTransactionsFlushTests: XCTestCase {
    func test_getWalletActivities_flushesRetainedPendingTransactionsBeforeRequestingHistory() async throws {
        let calls = CallRecorder()
        let service = try makeService(calls: calls)

        _ = try await service.getWalletActivities(
            state: MultichainWalletState(walletId: "wallet", addresses: []),
            limit: nil,
            cursor: nil,
            chain: .eth,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        let recorded = await calls.recorded
        XCTAssertEqual(recorded, [.flushRetainedPendingTransactions, .getWalletActivities])
    }

    func test_getWalletActivitiesByAssetId_flushesRetainedPendingTransactionsBeforeRequestingHistory() async throws {
        let calls = CallRecorder()
        let service = try makeService(calls: calls)

        _ = try await service.getWalletActivities(
            state: MultichainWalletState(walletId: "wallet", addresses: []),
            limit: nil,
            cursor: nil,
            assetId: "eth/mainnet/coin",
            activityTypeFilter: nil,
            hideDust: nil
        )

        let recorded = await calls.recorded
        XCTAssertEqual(recorded, [.flushRetainedPendingTransactions, .getWalletActivities])
    }

    func test_getWalletActivities_requestsHistory_whenFlushExceedsItsTimeLimit() async throws {
        let calls = CallRecorder()
        let service = try makeService(
            calls: calls,
            flushDuration: 10,
            pendingTransactionsFlushTimeLimit: 0.05
        )

        _ = try await service.getWalletActivities(
            state: MultichainWalletState(walletId: "wallet", addresses: []),
            limit: nil,
            cursor: nil,
            chain: .eth,
            assetId: nil,
            activityTypeFilter: nil,
            showPerps: nil,
            hideDust: nil
        )

        let recorded = await calls.recorded
        XCTAssertEqual(recorded, [.getWalletActivities])
    }
}

private extension MultichainServicePendingTransactionsFlushTests {
    func makeService(
        calls: CallRecorder,
        flushDuration: TimeInterval = 0,
        pendingTransactionsFlushTimeLimit: TimeInterval = MultichainServiceImplementation
            .defaultPendingTransactionsFlushTimeLimit
    ) throws -> MultichainService {
        let storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        return MultichainServiceImplementation(
            multichainClientAPI: MultichainActivitiesClientAPIStub(calls: calls),
            visibilityChangesController: VisibilityChangesController(
                vault: FileSystemVault(fileManager: .default, directory: storageDirectory),
                writer: MultichainActivitiesVisibilityChangesWriterStub()
            ),
            pendingTransactionsService: RecordingPendingTransactionsService(
                calls: calls,
                flushDuration: flushDuration
            ),
            pendingTransactionsFlushTimeLimit: pendingTransactionsFlushTimeLimit
        )
    }
}

private enum MultichainServiceCall: Equatable {
    case flushRetainedPendingTransactions
    case getWalletActivities
}

private actor CallRecorder {
    private(set) var recorded = [MultichainServiceCall]()

    func record(_ call: MultichainServiceCall) {
        recorded.append(call)
    }
}

private struct RecordingPendingTransactionsService: PendingTransactionsService {
    let calls: CallRecorder
    let flushDuration: TimeInterval

    func report(_: MultichainPendingTransaction) async {}

    func flushRetained() async {
        if flushDuration > 0 {
            try? await Task.sleep(nanoseconds: UInt64(flushDuration * 1_000_000_000))
        }
        await calls.record(.flushRetainedPendingTransactions)
    }
}

private struct MultichainActivitiesVisibilityChangesWriterStub: MultichainAssetVisibilityChangesWriter {
    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {}
}

private struct MultichainActivitiesClientAPIStub: MultichainClientAPI {
    let calls: CallRecorder

    func getWalletActivities(
        walletId _: String,
        limit _: Int?,
        cursor _: String?,
        chain _: MultichainChain?,
        assetId _: String?,
        activityTypeFilter _: MultichainActivityTypeFilter?,
        showPerps _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainClientAPIError) -> MultichainWalletActivitiesPage {
        await calls.record(.getWalletActivities)
        return MultichainWalletActivitiesPage(activities: [], nextCursor: nil)
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
