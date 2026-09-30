import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BackgroundUpdateLifecycleTests: XCTestCase {
    func test_startCreatesSessionForActiveWallet() async {
        let fixture = await makeFixture()

        fixture.backgroundUpdate.start()
        await fixture.awaitProcessedCommands()

        XCTAssertEqual(fixture.recorder.createdWalletIDs, [fixture.walletA.id])
    }

    func test_connectionStateDefaultsToConnectingBeforePipelineExists() async {
        let fixture = await makeFixture()

        XCTAssertEqual(
            fixture.backgroundUpdate.connectionState(walletID: fixture.walletA.id),
            .connecting
        )
    }

    func test_connectionStateSynchronouslyReadsPublishedState() async {
        let fixture = await makeFixture()
        let stream = fixture.backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()

        fixture.backgroundUpdate.start()
        _ = await iterator.next()
        _ = await iterator.next()

        XCTAssertEqual(
            fixture.backgroundUpdate.connectionState(walletID: fixture.walletA.id),
            .connected
        )
    }

    func test_repeatedStartReplacesSession() async {
        let fixture = await makeFixture()

        fixture.backgroundUpdate.start()
        fixture.backgroundUpdate.start()
        await fixture.awaitProcessedCommands()

        XCTAssertEqual(
            fixture.recorder.createdWalletIDs,
            [fixture.walletA.id, fixture.walletA.id]
        )
    }

    func test_reconnectDoesNotReplaceHealthySession() async {
        let fixture = await makeFixture()
        let stream = fixture.backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()

        fixture.backgroundUpdate.start()
        _ = await iterator.next()
        _ = await iterator.next()

        fixture.backgroundUpdate.reconnect()
        await fixture.awaitProcessedCommands()

        XCTAssertEqual(fixture.recorder.createdWalletIDs, [fixture.walletA.id])
    }

    func test_reconnectReplacesFailedSession() async {
        let provider = ScriptedLifecycleRunnerProvider()
        provider.append([
            StateOnlyLifecycleRunner(state: .noConnection),
            StateOnlyLifecycleRunner(state: .connected),
        ])
        let fixture = await makeFixture(runnerProvider: { provider.next(for: $0) })
        let stream = fixture.backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()

        fixture.backgroundUpdate.start()
        _ = await iterator.next()
        let failed = await iterator.next()
        XCTAssertEqual(failed?.state, .noConnection)

        fixture.backgroundUpdate.reconnect()
        let reconnecting = await iterator.next()
        let reconnected = await iterator.next()
        XCTAssertEqual(reconnecting?.state, .connecting)
        XCTAssertEqual(reconnected?.state, .connected)
        XCTAssertEqual(
            fixture.recorder.createdWalletIDs,
            [fixture.walletA.id, fixture.walletA.id]
        )
    }

    func test_startStopStartCreatesNewSession() async {
        let fixture = await makeFixture()

        fixture.backgroundUpdate.start()
        fixture.backgroundUpdate.stop()
        fixture.backgroundUpdate.start()
        await fixture.awaitProcessedCommands()

        XCTAssertEqual(
            fixture.recorder.createdWalletIDs,
            [fixture.walletA.id, fixture.walletA.id]
        )
    }

    func test_walletChangeWhileStoppedDoesNotCreateSession() async {
        let fixture = await makeFixture()

        await fixture.makeActive(fixture.walletB)
        await fixture.awaitProcessedCommands()

        XCTAssertTrue(fixture.recorder.createdWalletIDs.isEmpty)
    }

    func test_walletChangeAfterStopDoesNotResurrectSession() async {
        let fixture = await makeFixture()

        fixture.backgroundUpdate.start()
        fixture.backgroundUpdate.stop()
        await fixture.makeActive(fixture.walletB)
        await fixture.awaitProcessedCommands()

        XCTAssertEqual(fixture.recorder.createdWalletIDs, [fixture.walletA.id])
    }

    func test_walletChangeWhileRunningStartsSessionForNewWallet() async {
        let fixture = await makeFixture()

        fixture.backgroundUpdate.start()
        await fixture.makeActive(fixture.walletB)
        await fixture.awaitProcessedCommands()

        XCTAssertEqual(
            fixture.recorder.createdWalletIDs,
            [fixture.walletA.id, fixture.walletB.id]
        )
    }

    func test_nonSelectionWalletUpdatePreservesSelectionIdentity() async throws {
        let fixture = await makeFixture()
        let selection = try fixture.walletsStore.activeWalletSelection

        _ = await fixture.walletsStore.updateWalletMetaData(
            fixture.walletA,
            metaData: fixture.walletA.metaData
        )

        XCTAssertEqual(try fixture.walletsStore.activeWalletSelection, selection)
    }

    func test_subscriberReceivesConnectingBeforeConnectionResult() async {
        let fixture = await makeFixture()
        let stream = fixture.backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()

        fixture.backgroundUpdate.start()

        let first = await iterator.next()
        let second = await iterator.next()

        XCTAssertEqual(
            first,
            expectedUpdate(for: fixture.walletA, state: .connecting, fixture: fixture)
        )
        XCTAssertEqual(
            second,
            expectedUpdate(for: fixture.walletA, state: .connected, fixture: fixture)
        )
    }

    func test_subscriberRegisteredAfterStopReceivesConnectingSnapshot() async {
        let fixture = await makeFixture()
        let stream = fixture.backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()

        fixture.backgroundUpdate.start()
        _ = await iterator.next()
        _ = await iterator.next()

        fixture.backgroundUpdate.stop()

        let freshStream = fixture.backgroundUpdate.stateUpdates()
        var freshIterator = freshStream.makeAsyncIterator()
        let snapshot = await freshIterator.next()

        XCTAssertEqual(
            snapshot,
            expectedUpdate(for: fixture.walletA, state: .connecting, fixture: fixture)
        )
    }

    func test_stopDoesNotWakeExistingSubscriber() async {
        let fixture = await makeFixture()
        let stream = fixture.backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()

        fixture.backgroundUpdate.start()
        _ = await iterator.next()
        _ = await iterator.next()

        fixture.backgroundUpdate.stop()
        await fixture.makeActive(fixture.walletB)
        fixture.backgroundUpdate.start()

        // A stop-induced notification would show up here as `.connecting` for wallet A.
        let next = await iterator.next()

        XCTAssertEqual(
            next,
            expectedUpdate(for: fixture.walletB, state: .connecting, fixture: fixture)
        )
    }

    /// The wallet-switch reset lives here, not in the UI models: an existing subscriber must be told
    /// that `A` is connecting again, otherwise `A → B → A` would keep painting the `.connected` of
    /// the first session.
    func test_switchingBackToPreviousWalletRepublishesConnecting() async {
        let fixture = await makeFixture()
        let stream = fixture.backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()

        fixture.backgroundUpdate.start()
        _ = await iterator.next()
        let connected = await iterator.next()
        let firstSelectionID = connected?.walletSelectionID
        XCTAssertEqual(
            connected,
            expectedUpdate(for: fixture.walletA, state: .connected, fixture: fixture)
        )

        fixture.backgroundUpdate.stop()

        await fixture.makeActive(fixture.walletB)
        let switchedToB = await iterator.next()
        XCTAssertEqual(
            switchedToB,
            expectedUpdate(for: fixture.walletB, state: .connecting, fixture: fixture)
        )

        await fixture.makeActive(fixture.walletA)
        let switchedBackToA = await iterator.next()
        XCTAssertEqual(
            switchedBackToA,
            expectedUpdate(for: fixture.walletA, state: .connecting, fixture: fixture)
        )
        XCTAssertNotEqual(switchedBackToA?.walletSelectionID, firstSelectionID)
    }

    func test_cancelledSessionCannotPublishStateOrRawEventAfterSameWalletRestart() async {
        let provider = ScriptedLifecycleRunnerProvider()
        let fixture = await makeFixture(
            runnerProvider: { provider.next(for: $0) },
            eventCoalescingInterval: 0
        )
        let firstRunner = SuspendedLifecycleRunner(wallet: fixture.walletA)
        let secondRunner = SuspendedLifecycleRunner(wallet: fixture.walletA)
        provider.append([firstRunner, secondRunner])

        let staleEvent = expectation(description: "stale raw event")
        staleEvent.isInverted = true
        let eventObserver = LifecycleEventObserver { staleEvent.fulfill() }
        fixture.backgroundUpdate.addEventObserver(eventObserver) { observer, _, _ in
            observer.onEvent()
        }

        fixture.backgroundUpdate.start()
        await fulfillment(of: [firstRunner.started], timeout: 1)
        fixture.backgroundUpdate.start()
        await fulfillment(of: [secondRunner.started], timeout: 1)

        firstRunner.release()
        await fulfillment(of: [firstRunner.finished], timeout: 1)

        let snapshotStream = fixture.backgroundUpdate.stateUpdates()
        var snapshotIterator = snapshotStream.makeAsyncIterator()
        let snapshot = await snapshotIterator.next()
        XCTAssertEqual(
            snapshot,
            expectedUpdate(for: fixture.walletA, state: .connecting, fixture: fixture)
        )
        await fulfillment(of: [staleEvent], timeout: 0.1)

        fixture.backgroundUpdate.stop()
        await fixture.awaitProcessedCommands()
        secondRunner.release()
        await fulfillment(of: [secondRunner.finished], timeout: 1)
    }

    private func makeFixture(
        runnerProvider: ((Wallet) -> any WalletBackgroundUpdateRunning)? = nil,
        eventCoalescingInterval: TimeInterval = 2
    ) async -> Fixture {
        let walletA = makeWallet(id: "background-update-lifecycle-a", seed: 1)
        let walletB = makeWallet(id: "background-update-lifecycle-b", seed: 2)

        let keeperInfoStore = KeeperInfoStore(
            keeperInfoRepository: BackgroundUpdateKeeperInfoRepositoryFake()
        )
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        _ = await walletsStore.addWallets([walletA, walletB])
        _ = await walletsStore.makeWalletActive(walletA)

        let recorder = RunnerRecorder()
        let backgroundUpdate = BackgroundUpdate(
            walletStore: walletsStore,
            walletBackgroundUpdateProvider: { wallet in
                recorder.record(wallet.id)
                return runnerProvider?(wallet) ?? WalletBackgroundUpdate(
                    wallet: wallet,
                    streamingAPIV2Provider: StreamingAPIV2Provider { _ in nil }
                )
            },
            eventCoalescingInterval: eventCoalescingInterval
        )

        let fixture = Fixture(
            walletsStore: walletsStore,
            backgroundUpdate: backgroundUpdate,
            recorder: recorder,
            walletA: walletA,
            walletB: walletB
        )
        await fixture.drainStoreQueue()
        return fixture
    }

    private func expectedUpdate(
        for wallet: Wallet,
        state: BackgroundUpdateConnectionState,
        fixture: Fixture
    ) -> BackgroundUpdateStateUpdate {
        let selection = try! fixture.walletsStore.activeWalletSelection
        precondition(selection.walletID == wallet.id)
        return BackgroundUpdateStateUpdate(
            walletID: wallet.id,
            walletSelectionID: selection.selectionID,
            state: state
        )
    }

    private func makeWallet(id: String, seed: UInt8) -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: seed, count: 32))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "Wallet \(id)", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private struct Fixture {
    let walletsStore: WalletsStore
    let backgroundUpdate: BackgroundUpdate
    let recorder: RunnerRecorder
    let walletA: Wallet
    let walletB: Wallet

    /// Registering a subscriber is itself a command, so receiving its snapshot proves every command
    /// ordered before it has already been applied.
    func awaitProcessedCommands() async {
        let stream = backgroundUpdate.stateUpdates()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func makeActive(_ wallet: Wallet) async {
        _ = await walletsStore.makeWalletActive(wallet)
        await drainStoreQueue()
    }

    /// `Store.sendEvent` is dispatched behind the completion of `makeWalletActive`, so the wallet
    /// observation runs only after the store queue drains.
    func drainStoreQueue() async {
        let anchor = StoreAnchor()
        await withCheckedContinuation { continuation in
            walletsStore.addObserver(anchor, closure: { _, _ in }) {
                continuation.resume()
            }
        }
        withExtendedLifetime(anchor) {}
    }
}

private final class StoreAnchor {}

private final class RunnerRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var walletIDs = [String]()

    var createdWalletIDs: [String] {
        lock.withLock { walletIDs }
    }

    func record(_ walletID: String) {
        lock.withLock { walletIDs.append(walletID) }
    }
}

private final class ScriptedLifecycleRunnerProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var runners = [any WalletBackgroundUpdateRunning]()

    func append(_ runners: [any WalletBackgroundUpdateRunning]) {
        lock.withLock { self.runners.append(contentsOf: runners) }
    }

    func next(for _: Wallet) -> any WalletBackgroundUpdateRunning {
        lock.withLock { runners.removeFirst() }
    }
}

private final class StateOnlyLifecycleRunner: WalletBackgroundUpdateRunning, @unchecked Sendable {
    private let state: BackgroundUpdateConnectionState

    init(state: BackgroundUpdateConnectionState) {
        self.state = state
    }

    func run(
        stateHandler: @escaping @Sendable (BackgroundUpdateConnectionState) async -> Void,
        eventHandler _: @escaping @Sendable (BackgroundUpdateEvent) async -> Void
    ) async {
        await stateHandler(state)
    }
}

private final class SuspendedLifecycleRunner: WalletBackgroundUpdateRunning, @unchecked Sendable {
    let started = XCTestExpectation(description: "runner started")
    let finished = XCTestExpectation(description: "runner finished")

    private let wallet: Wallet
    private let lock = NSLock()
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func run(
        stateHandler: @escaping @Sendable (BackgroundUpdateConnectionState) async -> Void,
        eventHandler: @escaping @Sendable (BackgroundUpdateEvent) async -> Void
    ) async {
        started.fulfill()
        await withCheckedContinuation { continuation in
            let shouldResume = lock.withLock { () -> Bool in
                guard !isReleased else { return true }
                releaseContinuation = continuation
                return false
            }
            if shouldResume {
                continuation.resume()
            }
        }

        await stateHandler(.connected)
        await eventHandler(BackgroundUpdateEvent(wallet: wallet, lt: 1, txHash: "stale"))
        finished.fulfill()
    }

    func release() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            isReleased = true
            defer { releaseContinuation = nil }
            return releaseContinuation
        }
        continuation?.resume()
    }
}

private final class LifecycleEventObserver {
    let onEvent: () -> Void

    init(onEvent: @escaping () -> Void) {
        self.onEvent = onEvent
    }
}

private enum BackgroundUpdateLifecycleTestError: Error {
    case noKeeperInfo
}

private final class BackgroundUpdateKeeperInfoRepositoryFake: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw BackgroundUpdateLifecycleTestError.noKeeperInfo
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
