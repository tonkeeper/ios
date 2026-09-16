import BigInt
@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class VisibilityChangesControllerTests: XCTestCase {
    private let walletId = "wallet-1"
    private var storageDirectory: URL!
    private var writer: VisibilityChangesWriterMock!
    private var controller: VisibilityChangesController!

    override func setUp() {
        super.setUp()
        storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        writer = VisibilityChangesWriterMock()
        controller = VisibilityChangesController(vault: makeVault(), writer: writer)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storageDirectory)
        super.tearDown()
    }

    func test_fetchStartedBeforeSendCompletionKeepsOverlay() async throws {
        let asset = Self.makeAsset(assetId: "ton/mainnet/jetton/0:gram", isHidden: false)

        writer.gate()
        try enqueue(.hide, asset: asset)
        let raceToken = controller.beginServerFetch(walletId: walletId)

        writer.releaseGate()
        try await waitForPendingStoreFlush()

        controller.endServerFetch(walletId: walletId, token: raceToken)
        let afterRacedFetch = controller.applyingPendingChanges(to: [asset], walletId: walletId)
        XCTAssertEqual(afterRacedFetch.map(\.isHidden), [true])

        let freshToken = controller.beginServerFetch(walletId: walletId)
        controller.endServerFetch(walletId: walletId, token: freshToken)
        let afterObservedFetch = controller.applyingPendingChanges(to: [asset], walletId: walletId)
        XCTAssertEqual(afterObservedFetch.map(\.isHidden), [false])
    }

    func test_concurrentFetchesRetireOverlayAfterLastStaleFetchCompletes() async throws {
        let asset = Self.makeAsset(assetId: "ton/mainnet/jetton/0:gram", isHidden: false)

        let preSendToken = controller.beginServerFetch(walletId: walletId)
        try enqueue(.hide, asset: asset)
        try await waitForPendingStoreFlush()

        let postSendToken = controller.beginServerFetch(walletId: walletId)
        controller.endServerFetch(walletId: walletId, token: postSendToken)
        let whilePreSendFetchInflight = controller.applyingPendingChanges(to: [asset], walletId: walletId)
        XCTAssertEqual(whilePreSendFetchInflight.map(\.isHidden), [true])

        controller.endServerFetch(walletId: walletId, token: preSendToken)
        let afterPreSendFetch = controller.applyingPendingChanges(to: [asset], walletId: walletId)
        XCTAssertEqual(afterPreSendFetch.map(\.isHidden), [false])
    }

    func test_cancelledStaleFetchRetiresOverlayAfterFreshFetchCompletes() async throws {
        let asset = Self.makeAsset(assetId: "ton/mainnet/jetton/0:gram", isHidden: false)

        let preSendToken = controller.beginServerFetch(walletId: walletId)
        try enqueue(.hide, asset: asset)
        try await waitForPendingStoreFlush()

        let postSendToken = controller.beginServerFetch(walletId: walletId)
        controller.endServerFetch(walletId: walletId, token: postSendToken)
        XCTAssertEqual(
            controller.applyingPendingChanges(to: [asset], walletId: walletId).map(\.isHidden),
            [true]
        )

        controller.cancelServerFetch(walletId: walletId, token: preSendToken)
        XCTAssertEqual(
            controller.applyingPendingChanges(to: [asset], walletId: walletId).map(\.isHidden),
            [false]
        )
    }

    func test_sentShowReaddsAssetAbsentFromServerList() async throws {
        let asset = Self.makeAsset(assetId: "ton/mainnet/jetton/0:gram", isHidden: true)

        try enqueue(.show, asset: asset)
        try await waitForPendingStoreFlush()

        let overlayed = controller.applyingPendingChanges(to: [], walletId: walletId)
        XCTAssertEqual(overlayed.map(\.asset.assetId), [asset.asset.assetId])
        XCTAssertEqual(overlayed.map(\.isHidden), [false])

        let token = controller.beginServerFetch(walletId: walletId)
        controller.endServerFetch(walletId: walletId, token: token)
        XCTAssertTrue(controller.applyingPendingChanges(to: [], walletId: walletId).isEmpty)
    }

    func test_pendingChangeOverridesSentChangeAndSurvivesFetch() async throws {
        let asset = Self.makeAsset(assetId: "ton/mainnet/jetton/0:gram", isHidden: false)

        try enqueue(.hide, asset: asset)
        try await waitForPendingStoreFlush()

        writer.gate()
        try enqueue(.show, asset: asset)

        let serverStateAfterHide = [asset.settingHidden(true)]
        let overlayed = controller.applyingPendingChanges(to: serverStateAfterHide, walletId: walletId)
        XCTAssertEqual(overlayed.map(\.isHidden), [false])

        let token = controller.beginServerFetch(walletId: walletId)
        controller.endServerFetch(walletId: walletId, token: token)
        let afterFetch = controller.applyingPendingChanges(to: serverStateAfterHide, walletId: walletId)
        XCTAssertEqual(afterFetch.map(\.isHidden), [false])

        writer.releaseGate()
        try await waitForPendingStoreFlush()
    }
}

private extension VisibilityChangesControllerTests {
    func makeVault() -> FileSystemVault<PendingVisibilityChangesStore, String> {
        FileSystemVault(fileManager: .default, directory: storageDirectory)
    }

    func enqueue(_ action: MultichainAssetFilterAction, asset: MultichainAsset) throws {
        try controller.enqueue(
            [MultichainAssetFilterChange(assetId: asset.asset.assetId, action: action)],
            walletId: walletId,
            assets: [asset]
        )
    }

    func waitForPendingStoreFlush(
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let probe = VisibilityChangesController(vault: makeVault(), writer: VisibilityChangesWriterMock())
        for _ in 0 ..< 400 {
            if !probe.pendingSnapshot(walletId: walletId).hasChanges {
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("pending store was not flushed", file: file, line: line)
    }

    static func makeAsset(assetId: String, isHidden: Bool) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "Gram",
                symbol: "GRAM",
                decimals: 9,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            isHidden: isHidden,
            balance: BigUInt(1)
        )
    }
}

private final class VisibilityChangesWriterMock: MultichainAssetVisibilityChangesWriter, @unchecked Sendable {
    private let lock = NSLock()
    private var isGated = false
    private var gateContinuation: CheckedContinuation<Void, Never>?

    func gate() {
        lock.withLock { isGated = true }
    }

    func releaseGate() {
        let continuation: CheckedContinuation<Void, Never>? = lock.withLock {
            isGated = false
            defer { gateContinuation = nil }
            return gateContinuation
        }
        continuation?.resume()
    }

    func saveWalletAssetsFilters(
        walletId: String,
        changes: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {
        await withCheckedContinuation { continuation in
            let isWaiting: Bool = lock.withLock {
                guard isGated else { return false }
                precondition(gateContinuation == nil, "mock supports a single gated send")
                gateContinuation = continuation
                return true
            }
            if !isWaiting {
                continuation.resume()
            }
        }
    }
}
