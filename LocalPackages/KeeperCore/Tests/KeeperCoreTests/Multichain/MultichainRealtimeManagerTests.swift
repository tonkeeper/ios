import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class MultichainRealtimeManagerTests: XCTestCase {
    func test_balanceHint_notifiesObserver() async {
        let transport = FakeRealtimeTransport()
        let context = makeContext(transport: transport)
        let expectation = expectation(description: "balance hint")
        var receivedWalletId: String?

        context.manager.addBalanceChangeObserver(self) { _, walletId in
            receivedWalletId = walletId
            expectation.fulfill()
        }

        context.manager.handleSignalForTesting(
            .publication(
                walletId: context.walletId,
                payload: envelopeJSON(
                    event: "balance.hint",
                    walletId: context.walletId,
                    seq: 1
                )
            )
        )

        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(receivedWalletId, context.walletId)
    }

    func test_staleSeq_isDropped() async {
        let transport = FakeRealtimeTransport()
        let context = makeContext(transport: transport)
        let expectation = expectation(description: "first balance hint")
        expectation.expectedFulfillmentCount = 1
        var count = 0

        context.manager.addBalanceChangeObserver(self) { _, _ in
            count += 1
            expectation.fulfill()
        }

        let first = envelopeJSON(event: "balance.hint", walletId: context.walletId, seq: 5)
        let stale = envelopeJSON(event: "balance.hint", walletId: context.walletId, seq: 4)
        context.manager.handleSignalForTesting(.publication(walletId: context.walletId, payload: first))
        context.manager.handleSignalForTesting(.publication(walletId: context.walletId, payload: stale))

        await fulfillment(of: [expectation], timeout: 2)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(count, 1)
    }

    func test_balanceHint_isDebounced() async {
        let transport = FakeRealtimeTransport()
        let context = makeContext(transport: transport)
        let expectation = expectation(description: "debounced balance change")
        var count = 0

        context.manager.addBalanceChangeObserver(self) { _, _ in
            count += 1
            expectation.fulfill()
        }

        context.manager.handleSignalForTesting(
            .publication(
                walletId: context.walletId,
                payload: envelopeJSON(event: "balance.hint", walletId: context.walletId, seq: 1)
            )
        )
        context.manager.handleSignalForTesting(
            .publication(
                walletId: context.walletId,
                payload: envelopeJSON(event: "balance.hint", walletId: context.walletId, seq: 2)
            )
        )

        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(count, 1)
    }

    func test_activityHint_isDebounced() async {
        let transport = FakeRealtimeTransport()
        let context = makeContext(transport: transport)
        let expectation = expectation(description: "debounced history invalidation")
        var count = 0

        context.manager.addHistoryInvalidationObserver(self) { _, _ in
            count += 1
            expectation.fulfill()
        }

        context.manager.handleSignalForTesting(
            .publication(
                walletId: context.walletId,
                payload: envelopeJSON(event: "activity.hint", walletId: context.walletId, seq: 1)
            )
        )
        context.manager.handleSignalForTesting(
            .publication(
                walletId: context.walletId,
                payload: envelopeJSON(event: "activity.hint", walletId: context.walletId, seq: 2)
            )
        )

        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(count, 1)
    }

    func test_resubscribed_triggersBalanceAndHistory() async {
        let transport = FakeRealtimeTransport()
        let context = makeContext(transport: transport)
        let balanceExpectation = expectation(description: "balance resync")
        let historyExpectation = expectation(description: "history resync")

        context.manager.addBalanceChangeObserver(self) { _, _ in
            balanceExpectation.fulfill()
        }
        context.manager.addHistoryInvalidationObserver(self) { _, _ in
            historyExpectation.fulfill()
        }

        context.manager.handleSignalForTesting(.subscribed(walletId: context.walletId, resubscribed: true))

        await fulfillment(of: [balanceExpectation, historyExpectation], timeout: 2)
    }

    func test_subscription_tracksSubscribedWalletId() async {
        let transport = FakeRealtimeTransport()
        let context = makeContext(transport: transport)
        let subscribed = expectation(description: "subscribed")
        let unsubscribed = expectation(description: "unsubscribed")
        var observed: [String?] = []

        context.manager.addSubscriptionObserver(self) { _, walletId in
            observed.append(walletId)
            if walletId != nil {
                subscribed.fulfill()
            } else if !observed.isEmpty {
                unsubscribed.fulfill()
            }
        }

        context.manager.handleSignalForTesting(.subscribed(walletId: context.walletId, resubscribed: false))
        await fulfillment(of: [subscribed], timeout: 1)
        XCTAssertTrue(context.manager.isSubscribed(walletId: context.walletId))

        context.manager.handleSignalForTesting(.unsubscribed(walletId: context.walletId))
        await fulfillment(of: [unsubscribed], timeout: 1)
        XCTAssertFalse(context.manager.isSubscribed(walletId: context.walletId))
        XCTAssertEqual(observed, [context.walletId, nil])
    }

    func test_configurationChangeReconnectsActiveWalletAndIgnoresUnchangedEndpoint() async throws {
        let initial = expectation(description: "initial connection")
        let changed = expectation(description: "new endpoint")
        let disconnected = expectation(description: "background disconnect")
        let endpoint = RealtimeEndpointBox()
        let transport = FakeRealtimeTransport(onConnect: { url in
            if url == BootConfiguration.defaultMultichainRealtimeURL {
                initial.fulfill()
            } else {
                changed.fulfill()
            }
        }, onDisconnect: { count in
            if count == 2 { disconnected.fulfill() }
        })
        let context = makeContext(transport: transport, endpointProvider: { endpoint.value })
        await context.walletsStore.addWallets([makeWallet(walletId: context.walletId)])
        context.manager.setForeground(true)
        await fulfillment(of: [initial], timeout: 1)

        endpoint.value = try XCTUnwrap(URL(string: "wss://moved.example.com/connection/websocket"))
        context.manager.configurationDidChange()
        await fulfillment(of: [changed], timeout: 1)
        context.manager.configurationDidChange()
        context.manager.setForeground(false)
        await fulfillment(of: [disconnected], timeout: 1)

        XCTAssertEqual(transport.connections, [
            BootConfiguration.defaultMultichainRealtimeURL,
            endpoint.value,
        ])
        XCTAssertEqual(transport.disconnectCount, 2)
    }

    func test_replacedConnectionCannotUnsubscribeOrDisableCurrentConnection() async throws {
        let initial = expectation(description: "initial")
        let changed = expectation(description: "changed")
        let currentPublication = expectation(description: "current publication")
        let endpoint = RealtimeEndpointBox()
        let transport = FakeRealtimeTransport(onConnect: { url in
            (url == BootConfiguration.defaultMultichainRealtimeURL ? initial : changed).fulfill()
        })
        let context = makeContext(transport: transport, endpointProvider: { endpoint.value })
        await context.walletsStore.addWallets([makeWallet(walletId: context.walletId)])
        context.manager.setForeground(true)
        await fulfillment(of: [initial], timeout: 1)
        let oldSignal = try XCTUnwrap(transport.signalHandler)
        let oldDisabled = try XCTUnwrap(transport.disabledHandler)

        endpoint.value = try XCTUnwrap(URL(string: "wss://moved.example.com/connection/websocket"))
        context.manager.configurationDidChange()
        await fulfillment(of: [changed], timeout: 1)
        let currentSignal = try XCTUnwrap(transport.signalHandler)
        context.manager.addBalanceChangeObserver(self) { _, _ in currentPublication.fulfill() }
        currentSignal(.subscribed(walletId: context.walletId, resubscribed: false))
        oldSignal(.unsubscribed(walletId: context.walletId))
        oldDisabled()
        currentSignal(.publication(
            walletId: context.walletId,
            payload: envelopeJSON(event: "balance.hint", walletId: context.walletId, seq: 1)
        ))
        await fulfillment(of: [currentPublication], timeout: 2)
        XCTAssertTrue(context.manager.isSubscribed(walletId: context.walletId))
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_configurationChangeInBackgroundWaitsForForeground() async throws {
        let connected = expectation(description: "foreground connection")
        let disconnected = expectation(description: "background disconnect")
        let endpoint = RealtimeEndpointBox()
        let transport = FakeRealtimeTransport(onConnect: { _ in connected.fulfill() }, onDisconnect: { _ in
            disconnected.fulfill()
        })
        let context = makeContext(transport: transport, endpointProvider: { endpoint.value })
        await context.walletsStore.addWallets([makeWallet(walletId: context.walletId)])
        endpoint.value = try XCTUnwrap(URL(string: "wss://moved.example.com/connection/websocket"))
        context.manager.configurationDidChange()
        context.manager.setForeground(true)
        await fulfillment(of: [connected], timeout: 1)
        context.manager.setForeground(false)
        await fulfillment(of: [disconnected], timeout: 1)

        XCTAssertEqual(transport.connections, [endpoint.value])
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_tokenSource_mapsForbiddenAndDisabled() async {
        let forbiddenAPI = RealtimeTokenClientAPIStub(error: .forbidden(message: "wrong wallet"))
        let forbiddenSource = RealtimeTokenSource(clientAPI: forbiddenAPI)
        let forbidden = await forbiddenSource.subscriptionToken(walletId: "wallet")
        XCTAssertEqual(forbidden, .forbidden)

        let disabledAPI = RealtimeTokenClientAPIStub(error: .badStatus(message: "realtime_disabled"))
        let disabledSource = RealtimeTokenSource(clientAPI: disabledAPI)
        let disabled = await disabledSource.connectionToken()
        XCTAssertEqual(disabled, .disabledByBackend)
    }
}

private extension MultichainRealtimeManagerTests {
    struct Context {
        let walletId: String
        let manager: MultichainRealtimeManager
        let walletsStore: WalletsStore
    }

    func makeContext(
        transport: FakeRealtimeTransport,
        endpointProvider: @escaping () -> URL = { BootConfiguration.defaultMultichainRealtimeURL }
    ) -> Context {
        let walletId = "aia3n6aaiisrysg6tgismssvepwp7ozumgba"
        let walletsStore = WalletsStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfoRepository()))
        let manager = MultichainRealtimeManager(
            walletsStore: walletsStore,
            transport: transport,
            endpointProvider: endpointProvider
        )
        manager.start()
        return Context(walletId: walletId, manager: manager, walletsStore: walletsStore)
    }

    func makeWallet(walletId: String) -> Wallet {
        Wallet(
            id: "wallet",
            identity: .init(network: .mainnet, kind: .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(.init(walletId: walletId, addresses: [.init(chain: .tron, address: "tron-address")]))
        )
    }

    func envelopeJSON(event: String, walletId: String, seq: Int64) -> Data {
        Data(
            """
            {"v":1,"event":"\(event)","wallet_id":"\(walletId)","seq":\(seq),"ts":"2026-08-31T12:20:09.363Z","data":{}}
            """.utf8
        )
    }
}

private final class RealtimeEndpointBox {
    private let lock = NSLock()
    private var endpoint = BootConfiguration.defaultMultichainRealtimeURL

    var value: URL {
        get { lock.withLock { endpoint } }
        set { lock.withLock { endpoint = newValue } }
    }
}

private final class FakeRealtimeTransport: MultichainRealtimeTransport {
    private let lock = NSLock()
    private var storedConnections = [URL]()
    private var storedDisconnectCount = 0
    private var storedSignalHandler: ((MultichainRealtimeSignal) -> Void)?
    private var storedDisabledHandler: (() -> Void)?
    private let onConnect: (URL) -> Void
    private let onDisconnect: (Int) -> Void

    init(onConnect: @escaping (URL) -> Void = { _ in }, onDisconnect: @escaping (Int) -> Void = { _ in }) {
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }

    var connections: [URL] {
        lock.withLock { storedConnections }
    }

    var disconnectCount: Int {
        lock.withLock { storedDisconnectCount }
    }

    func connect(walletId _: String, endpoint: URL) {
        lock.withLock { storedConnections.append(endpoint) }
        onConnect(endpoint)
    }

    func disconnect() {
        let count = lock.withLock {
            storedDisconnectCount += 1
            return storedDisconnectCount
        }
        onDisconnect(count)
    }

    var signalHandler: ((MultichainRealtimeSignal) -> Void)? {
        lock.withLock { storedSignalHandler }
    }

    var disabledHandler: (() -> Void)? {
        lock.withLock { storedDisabledHandler }
    }

    func setSignalHandler(_ handler: @escaping (MultichainRealtimeSignal) -> Void) {
        lock.withLock { storedSignalHandler = handler }
    }

    func setDisabledByBackendHandler(_ handler: @escaping () -> Void) {
        lock.withLock { storedDisabledHandler = handler }
    }
}

private struct RealtimeTokenClientAPIStub: MultichainClientAPI {
    let error: MultichainClientAPIError

    func healthcheck() async throws(MultichainClientAPIError) -> MultichainHealth {
        throw error
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainClientAPIError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw error
    }

    func getWallet(walletId _: String) async throws(MultichainClientAPIError) -> MultichainRegisteredWallet {
        throw error
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainClientAPIError) -> MultichainWalletSyncStatus {
        throw error
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
        throw error
    }

    func saveWalletAssetsFilters(walletId _: String, changes _: [MultichainAssetFilterChange]) async throws(MultichainClientAPIError) {
        throw error
    }

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
        throw error
    }

    func getWalletChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        throw error
    }

    func broadcastTx(chain _: MultichainChain, signedTransaction _: Data) async throws(MultichainClientAPIError) -> MultichainBroadcastResult {
        throw error
    }

    func addPendingTransaction(_: MultichainPendingTransaction) async throws(MultichainClientAPIError) {
        throw error
    }

    func getFees(chain _: MultichainChain) async throws(MultichainClientAPIError) -> MultichainFeeEstimate {
        throw error
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainClientAPIError) -> [MultichainRaffle] {
        throw error
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainClientAPIError) {
        throw error
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainClientAPIError) {
        throw error
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainClientAPIError) {
        throw error
    }

    func getRealtimeConnectionToken() async throws(MultichainClientAPIError) -> String {
        throw error
    }

    func getWalletRealtimeToken(walletId _: String) async throws(MultichainClientAPIError) -> String {
        throw error
    }
}

private final class EmptyKeeperInfoRepository: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw NSError(domain: "test", code: 1)
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}
    func removeKeeperInfo() throws {}
}
