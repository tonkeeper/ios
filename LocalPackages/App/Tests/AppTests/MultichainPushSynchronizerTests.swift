@testable import App
import Foundation
import XCTest

final class MultichainPushSynchronizerTests: XCTestCase {
    func test_emptySet_unsubscribesWithoutPushToken() async {
        let context = Context(synced: MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1"))
        context.token = nil

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.unsubscribeCount, 1)
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: [], token: nil, deviceId: "device-1")
        )
    }

    func test_emptySet_doesNotAuthenticateWhenNothingWasSynced() async {
        let context = Context(synced: MultichainPushSyncState())

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.deviceIdCount, 0)
        XCTAssertEqual(context.unsubscribeCount, 0)
    }

    func test_emptySet_staysSilentWhenAlreadyDropped() async {
        let context = Context(synced: MultichainPushSyncState(walletIds: [], token: nil, deviceId: "device-1"))

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.unsubscribeCount, 0)
    }

    func test_emptySet_unsubscribesAgainOnANewDevice() async {
        let context = Context(synced: MultichainPushSyncState(walletIds: [], token: nil, deviceId: "device-0"))

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.unsubscribeCount, 1)
        XCTAssertEqual(context.synced.deviceId, "device-1")
    }

    /// The request may still have been applied after it left the device, so the recorded scope is
    /// no longer confirmed — but the wallet set is still the best guess at what is subscribed.
    func test_emptySet_invalidatesTheConfirmedScopeWhenUnsubscribeFails() async {
        let synced = MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1")
        let context = Context(synced: synced)
        context.unsubscribeError = PushSyncFailure.offline

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: ["a"], token: nil, deviceId: nil)
        )
    }

    func test_emptySet_unsubscribesAgainAfterAnAmbiguousFailure() async {
        let context = Context(
            synced: MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1")
        )
        context.unsubscribeError = PushSyncFailure.offline

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value
        context.unsubscribeError = nil
        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.unsubscribeCount, 2)
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: [], token: nil, deviceId: "device-1")
        )
    }

    // MARK: - Cache key transitions

    func test_subscribe_sendsTheFullSetAndRecordsIt() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a", "b"]

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.subscribed.map(\.walletIds), [["a", "b"]])
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: ["a", "b"], token: "fcm", deviceId: "device-1")
        )
    }

    func test_subscribe_skipsWhenDeviceTokenAndSetAreUnchanged() async {
        let context = Context(synced: MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1"))
        context.desired = ["a"]

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertTrue(context.subscribed.isEmpty)
    }

    func test_subscribe_resendsWhenDeviceRotated() async {
        let context = Context(synced: MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-0"))
        context.desired = ["a"]

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        // The subscription lives on the device id, so the same token and set still have to be resent.
        XCTAssertEqual(context.subscribed.map(\.walletIds), [["a"]])
        XCTAssertEqual(context.synced.deviceId, "device-1")
    }

    func test_subscribe_resendsWhenPushTokenRotated() async {
        let context = Context(synced: MultichainPushSyncState(walletIds: ["a"], token: "fcm-old", deviceId: "device-1"))
        context.desired = ["a"]

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.subscribed.map(\.token), ["fcm"])
        XCTAssertEqual(context.synced.token, "fcm")
    }

    func test_subscribe_deferredWhenTokenCannotBeResolved() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.token = nil

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertTrue(context.subscribed.isEmpty)
        XCTAssertEqual(context.synced, MultichainPushSyncState())
    }

    func test_subscribe_deferredWhenDeviceSessionIsUnavailable() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.deviceIdError = PushSyncFailure.offline

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertTrue(context.subscribed.isEmpty)
        XCTAssertEqual(context.synced, MultichainPushSyncState())
    }

    /// The set must not be recorded as sent, but `nil` cannot stand either: it claims there is no
    /// subscription to drop, and a first subscribe that timed out may have created one.
    func test_subscribe_marksTheScopeUnconfirmedWhenTheFirstRequestFails() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.subscribeError = PushSyncFailure.offline

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: [], token: nil, deviceId: nil)
        )
    }

    /// The rollback that follows a failed first subscribe leaves the desired set empty. Without the
    /// marker the compensating pass would decide this install never synced and send nothing.
    func test_subscribe_unsubscribesAfterTheRollbackOfAFailedFirstSubscribe() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.subscribeError = PushSyncFailure.offline

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value
        context.desired = []
        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.unsubscribeCount, 1)
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: [], token: nil, deviceId: "device-1")
        )
    }

    /// Without invalidating the recorded scope the next pass would see an unchanged set and skip
    /// the request, leaving a subscription that may have landed after the timeout.
    func test_subscribe_resendsAfterAnAmbiguousFailure() async {
        let context = Context(
            synced: MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1")
        )
        context.desired = ["a", "b"]
        context.subscribeError = PushSyncFailure.offline

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value
        context.subscribeError = nil
        context.desired = ["a"]
        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(context.subscribed.map(\.walletIds), [["a", "b"], ["a"]])
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1")
        )
    }

    // MARK: - Outcome reported to the toggle

    /// The toggle is written to the store before the request goes out, so the caller reverts it on
    /// anything short of a confirmed set — a deferral leaves the user with a subscription that
    /// does not exist just as much as a rejected request does.
    func test_outcome_isFailedWhenTheRequestFails() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.subscribeError = PushSyncFailure.offline

        let outcome = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(outcome, .failed)
    }

    func test_outcome_isFailedWhenTheDeviceSessionIsUnavailable() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.deviceIdError = PushSyncFailure.offline

        let outcome = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(outcome, .failed)
    }

    /// The token's arrival reconciles the subscriptions on its own, so the toggle must stay where
    /// the user put it — a wallet enabled before the first FCM token is not a rejection.
    func test_outcome_isDeferredWhenTheTokenCannotBeResolved() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.token = nil

        let outcome = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(outcome, .deferred)
    }

    func test_outcome_isSettledWhenTheSetReachesTheBackend() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]

        let outcome = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(outcome, .settled)
    }

    /// Turning off the only wallet that never synced needs no request, and the toggle is already
    /// where the user put it.
    func test_outcome_isSettledWhenThereIsNothingToDo() async {
        let context = Context(synced: MultichainPushSyncState())

        let outcome = await context.synchronizer.schedule(requireAuthorization: false)?.value

        XCTAssertEqual(outcome, .settled)
    }

    func test_schedule_requestsNotificationAuthorizationOnlyWhenAsked() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value
        XCTAssertEqual(context.authorizationCount, 0)

        context.desired = ["a", "b"]
        _ = await context.synchronizer.schedule(requireAuthorization: true)?.value
        XCTAssertEqual(context.authorizationCount, 1)
    }

    // MARK: - Overlapping operations

    func test_schedule_chainsOverlappingSyncsInsteadOfCancelling() async {
        let context = Context(synced: MultichainPushSyncState())
        context.subscribeGate = AsyncGate()
        context.desired = ["a"]

        let first = context.synchronizer.schedule(requireAuthorization: false)
        await context.didStartSubscribe.wait()
        context.desired = ["a", "b"]
        let second = context.synchronizer.schedule(requireAuthorization: false)
        context.subscribeGate?.open()
        _ = await first?.value
        _ = await second?.value

        // A cancelled request can still land on the backend, so the newer set is sent after the
        // in-flight one instead of replacing it, and the recorded state describes the newer set.
        XCTAssertEqual(context.subscribed.map(\.walletIds), [["a"], ["a", "b"]])
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: ["a", "b"], token: "fcm", deviceId: "device-1")
        )
        XCTAssertEqual(context.savedCount, 2)
    }

    func test_schedule_unsubscribesAfterAnInFlightSubscribeWasSupersededByAnEmptySet() async {
        let context = Context(synced: MultichainPushSyncState())
        context.subscribeGate = AsyncGate()
        context.desired = ["a"]

        let first = context.synchronizer.schedule(requireAuthorization: false)
        await context.didStartSubscribe.wait()
        context.desired = []
        let second = context.synchronizer.schedule(requireAuthorization: false)
        context.subscribeGate?.open()
        _ = await first?.value
        _ = await second?.value

        XCTAssertEqual(context.subscribed.count, 1)
        XCTAssertEqual(context.unsubscribeCount, 1)
        XCTAssertEqual(context.savedCount, 2)
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: [], token: nil, deviceId: "device-1")
        )
    }

    func test_schedule_resubscribesAfterAnInFlightUnsubscribeWasSupersededByANonEmptySet() async {
        let context = Context(
            synced: MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1")
        )
        context.unsubscribeGate = AsyncGate()
        context.desired = []

        let first = context.synchronizer.schedule(requireAuthorization: false)
        await context.didStartUnsubscribe.wait()
        context.desired = ["a"]
        let second = context.synchronizer.schedule(requireAuthorization: false)
        context.unsubscribeGate?.open()
        _ = await first?.value
        _ = await second?.value

        XCTAssertEqual(context.unsubscribeCount, 1)
        XCTAssertEqual(context.subscribed.map(\.walletIds), [["a"]])
        XCTAssertEqual(context.savedCount, 2)
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1")
        )
    }

    func test_schedule_doesNotStartSupersededUnsubscribeAfterResolvingDeviceId() async {
        let synced = MultichainPushSyncState(walletIds: ["a"], token: "fcm", deviceId: "device-1")
        let context = Context(synced: synced)
        context.deviceIdGate = AsyncGate()
        context.subscribeError = PushSyncFailure.offline

        let first = context.synchronizer.schedule(requireAuthorization: false)
        await context.didStartDeviceId.wait()
        context.desired = ["b"]
        let second = context.synchronizer.schedule(requireAuthorization: false)
        context.deviceIdGate?.open()
        _ = await first?.value
        _ = await second?.value

        XCTAssertEqual(context.unsubscribeCount, 0)
        XCTAssertEqual(context.subscribed.map(\.walletIds), [["b"]])
        // The failed subscribe leaves the scope unconfirmed, but must not record `["b"]` as sent.
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: synced.walletIds, token: nil, deviceId: nil)
        )
    }

    /// The failing successor must not overwrite the set its predecessor confirmed — only the scope,
    /// so the next pass re-sends instead of trusting a state the backend never acknowledged.
    func test_schedule_keepsTheConfirmedSetWhenTheSuccessorFails() async {
        let context = Context(synced: MultichainPushSyncState())
        context.subscribeGate = AsyncGate()
        context.subscribeErrorCall = 2
        context.desired = ["a"]

        let first = context.synchronizer.schedule(requireAuthorization: false)
        await context.didStartSubscribe.wait()
        context.desired = ["a", "b"]
        let second = context.synchronizer.schedule(requireAuthorization: false)
        context.subscribeGate?.open()
        _ = await first?.value
        _ = await second?.value

        XCTAssertEqual(context.subscribed.map(\.walletIds), [["a"], ["a", "b"]])
        XCTAssertEqual(
            context.synced,
            MultichainPushSyncState(walletIds: ["a"], token: nil, deviceId: nil)
        )
    }

    /// A superseded pass reports `settled` because the newer one carries its change — so a caller
    /// that only awaits its own pass never learns the newer one failed.
    func test_settledOutcome_reportsTheFailureOfThePassThatSupersededTheCaller() async {
        let context = Context(synced: MultichainPushSyncState())
        context.deviceIdGate = AsyncGate()
        context.desired = ["a"]

        let first = context.synchronizer.schedule(requireAuthorization: false)
        await context.didStartDeviceId.wait()
        context.desired = ["a", "b"]
        context.subscribeError = PushSyncFailure.offline
        let second = context.synchronizer.schedule(requireAuthorization: false)
        context.deviceIdGate?.open()

        let outcomes = await(first?.value, second?.value)
        XCTAssertEqual(outcomes.0, .settled)
        XCTAssertEqual(outcomes.1, .failed)
        let settled = await context.synchronizer.settledOutcome()
        XCTAssertEqual(settled, .failed)
    }

    func test_settledOutcome_waitsForAPassScheduledWhileItWasAwaiting() async {
        let context = Context(synced: MultichainPushSyncState())
        context.subscribeGate = AsyncGate()
        context.desired = ["a"]

        _ = context.synchronizer.schedule(requireAuthorization: false)
        await context.didStartSubscribe.wait()
        let settled = Task { await context.synchronizer.settledOutcome() }
        context.desired = ["a", "b"]
        context.subscribeError = PushSyncFailure.offline
        _ = context.synchronizer.schedule(requireAuthorization: false)
        context.subscribeGate?.open()

        let outcome = await settled.value
        XCTAssertEqual(outcome, .failed)
    }

    func test_settledOutcome_isDeferredWhenTheTailIsWaitingForAToken() async {
        let context = Context(synced: MultichainPushSyncState())
        context.desired = ["a"]
        context.token = nil

        _ = await context.synchronizer.schedule(requireAuthorization: false)?.value
        let settled = await context.synchronizer.settledOutcome()

        XCTAssertEqual(settled, .deferred)
    }

    func test_settledOutcome_isSettledWithNothingScheduled() async {
        let context = Context(synced: MultichainPushSyncState())

        let settled = await context.synchronizer.settledOutcome()

        XCTAssertEqual(settled, .settled)
    }
}

// MARK: -

private enum PushSyncFailure: Error {
    case offline
}

private final class Context: @unchecked Sendable {
    var desired = [String]()
    var token: String? = "fcm"
    var synced: MultichainPushSyncState
    var deviceIdError: Error?
    var subscribeError: Error?
    var subscribeErrorCall: Int?
    var unsubscribeError: Error?
    var deviceIdGate: AsyncGate?
    /// Holds `subscribe` open so a test can interleave a second schedule with an in-flight sync.
    var subscribeGate: AsyncGate?
    var unsubscribeGate: AsyncGate?
    let didStartDeviceId = AsyncGate()
    let didStartSubscribe = AsyncGate()
    let didStartUnsubscribe = AsyncGate()
    private(set) var deviceIdCount = 0
    private(set) var unsubscribeCount = 0
    private(set) var authorizationCount = 0
    private(set) var savedCount = 0
    private(set) var subscribed = [(token: String, walletIds: [String])]()

    lazy var synchronizer = MultichainPushSynchronizer(
        dependencies: MultichainPushSynchronizerDependencies(
            desiredWalletIds: { [unowned self] in desired },
            loadState: { [unowned self] in synced },
            saveState: { [unowned self] state in
                savedCount += 1
                synced = state
            },
            deviceId: { [unowned self] in
                deviceIdCount += 1
                didStartDeviceId.open()
                if let deviceIdGate {
                    await deviceIdGate.wait()
                }
                if let deviceIdError {
                    throw deviceIdError
                }
                return "device-1"
            },
            resolveToken: { [unowned self] hint in hint ?? token },
            requestAuthorization: { [unowned self] in authorizationCount += 1 },
            subscribe: { [unowned self] token, walletIds in
                subscribed.append((token, walletIds))
                didStartSubscribe.open()
                if let subscribeGate {
                    await subscribeGate.wait()
                }
                if let subscribeErrorCall, subscribeErrorCall == subscribed.count {
                    throw PushSyncFailure.offline
                }
                if let subscribeError {
                    throw subscribeError
                }
            },
            unsubscribe: { [unowned self] in
                unsubscribeCount += 1
                didStartUnsubscribe.open()
                if let unsubscribeGate {
                    await unsubscribeGate.wait()
                }
                if let unsubscribeError {
                    throw unsubscribeError
                }
            }
        )
    )

    init(synced: MultichainPushSyncState) {
        self.synced = synced
    }
}

/// Blocks a dependency until the test opens it, so overlapping syncs interleave deterministically.
private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [UnsafeContinuation<Void, Never>]()
    private var isOpen = false

    func wait() async {
        await withUnsafeContinuation { continuation in
            lock.lock()
            guard !isOpen else {
                lock.unlock()
                continuation.resume()
                return
            }
            continuations.append(continuation)
            lock.unlock()
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let pending = continuations
        continuations = []
        lock.unlock()
        pending.forEach { $0.resume() }
    }
}
