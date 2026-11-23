@testable import App
import Foundation
import KeeperCore
import TKTestSupport
import XCTest

@available(iOS 16.2, *)
@MainActor
final class TransactionLiveActivityPushRegistrarTests: XCTestCase {
    private typealias Content = TransactionLiveActivityPushRegistrar.Content

    private var server: FakeServer!
    private var registrar: TransactionLiveActivityPushRegistrar!
    private var now = Date(timeIntervalSinceReferenceDate: 0)

    override func setUp() async throws {
        server = FakeServer()
        let server = server!
        registrar = TransactionLiveActivityPushRegistrar(
            register: { try await server.register($0) },
            unregister: { try await server.unregister($0) },
            deviceId: { server.deviceId },
            pushSubscription: { server.pushSubscription },
            now: { [unowned self] in now }
        )
    }

    func test_registersOnceBothTheTokenAndThePendingContentAreKnown() async {
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls, [])

        registrar.tokenChanged(Data([0x0A, 0xFF]), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [.register("a", token: "0aff", tx: "ton:1")])
    }

    func test_sendsTheSameRegistrationOnceAndAChangedOneAgain() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:2"),
        ])
    }

    func test_changesQueuedTogetherSendOnlyTheLatest() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [.register("a", token: "01", tx: "ton:2")])
    }

    func test_anOutcomeRegistersNothingAndKeepsTheServerRecord() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(nil, activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [])
    }

    func test_aFailedRegistrationWaitsBeforeItGoesOutAgain() async {
        server.failsNextRegister = true
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        now += 9
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls.count, 1)

        now += 1
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:1"),
        ])
    }

    func test_aChangeAfterAFailureGoesOutAtOnce() async {
        server.failsNextRegister = true
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:2"),
        ])
    }

    func test_aFailedSwitchToAnotherTransactionUnregistersTheOldOne() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.failsNextRegister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls.suffix(2), [.register("a", token: "01", tx: "ton:2"), .unregister("a")])

        now += 10
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls.last, .register("a", token: "01", tx: "ton:2"))
    }

    func test_aRejectedSwitchToAnotherTransactionUnregistersTheOldOne() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.rejectsNextRegister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls.suffix(2), [.register("a", token: "01", tx: "ton:2"), .unregister("a")])
    }

    func test_aFailedUnregisterAfterAFailedSwitchGoesOutAgain() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.failsNextRegister = true
        server.failsNextUnregister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        now += 10
        server.failsNextRegister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:2"),
            .unregister("a"),
            .register("a", token: "01", tx: "ton:2"),
            .unregister("a"),
        ])
    }

    func test_aFailedUnregisterAfterARejectedSwitchGoesOutAgain() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.rejectsNextRegister = true
        server.failsNextUnregister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        now += 9
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls.count, 3)

        now += 1
        server.rejectsNextRegister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls.suffix(2), [.register("a", token: "01", tx: "ton:2"), .unregister("a")])
    }

    func test_aFailedUpdateOfTheSameTransactionKeepsItsRecord() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.failsNextRegister = true
        registrar.contentChanged(content(alertBody: "20 TON"), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:1"),
        ])
    }

    func test_aRegistrationTheServerRejectedGoesOutAgainOnlyChanged() async {
        server.rejectsNextRegister = true
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        now += 60
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls.count, 1)

        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()
        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:2"),
        ])
    }

    func test_aRejectedRegistrationGoesOutAgainOnceThePushSubscriptionChanges() async {
        server.rejectsNextRegister = true
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.pushSubscription = ["fcm-1", "wallet-1"]
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:1"),
        ])
    }

    func test_returningToTheLastSentContentAfterAFailureRegistersItAgain() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.failsNextRegister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:2"),
            .unregister("a"),
            .register("a", token: "01", tx: "ton:1"),
        ])
    }

    func test_aNewDeviceGetsTheRegistrationAgain() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        server.deviceId = "device-2"
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls.count, 2)
    }

    func test_redactionUpdatesTheRegistrationWithoutANewSnapshot() async {
        let original = content()
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(original, activityId: "a")
        await registrar.waitUntilIdle()

        let redacted = Data(#"{"transactionId":"ton:1","source":{"currency":"TON"}}"#.utf8)
        registrar.redactContent(redacted, alertBody: "TON", activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.registrations.count, 2)
        XCTAssertEqual(server.registrations.last?.contentState, redacted)
        XCTAssertEqual(server.registrations.last?.alertBody, "TON")
        XCTAssertEqual(server.registrations.last?.finalTitles, original.finalTitles)
    }

    func test_redactionForgetsARestoredRegistrationWithoutKnownContent() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.redactContent(Data(#"{"transactionId":"ton:1"}"#.utf8), alertBody: "", activityId: "a")
        await registrar.waitUntilIdle()
        registrar.tokenChanged(Data([2]), activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [.unregister("a")])
    }

    func test_redactionAfterAFailedSwitchUnregistersTheOldTransactionInsteadOfMixingThem() async {
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        server.failsNextRegister = true
        server.failsNextUnregister = true
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        await registrar.waitUntilIdle()
        registrar.contentChanged(nil, activityId: "a")

        registrar.redactContent(Data(#"{"transactionId":"ton:2","status":"unknown"}"#.utf8), alertBody: "TON", activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [
            .register("a", token: "01", tx: "ton:1"),
            .register("a", token: "01", tx: "ton:2"),
            .unregister("a"),
            .unregister("a"),
        ])
    }

    func test_redactionKeepsTheRecordOfAnActivityThatShowsAnOutcome() async {
        let original = content()
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(original, activityId: "a")
        await registrar.waitUntilIdle()
        registrar.contentChanged(nil, activityId: "a")

        let redacted = Data(#"{"transactionId":"ton:1","status":"unknown"}"#.utf8)
        registrar.redactContent(redacted, alertBody: "TON", activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.registrations.map(\.contentState), [original.contentState, redacted])
        XCTAssertEqual(server.registrations.last?.finalTitles, original.finalTitles)
    }

    func test_redactionUnregistersARestoredActivityBeforeItsTokenArrivesOnce() async {
        registrar.redactContent(Data(#"{"transactionId":"ton:1"}"#.utf8), alertBody: "", activityId: "a")
        registrar.redactContent(Data(#"{"transactionId":"ton:1"}"#.utf8), alertBody: "", activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [.unregister("a")])
    }

    func test_aFailedUnregisterOnRedactionGoesOutAgainOnTheNextRedaction() async {
        server.failsNextUnregister = true
        registrar.redactContent(Data(#"{"transactionId":"ton:1"}"#.utf8), alertBody: "", activityId: "a")
        await registrar.waitUntilIdle()
        registrar.redactContent(Data(#"{"transactionId":"ton:1"}"#.utf8), alertBody: "", activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [.unregister("a"), .unregister("a")])
    }

    func test_aRegistrationAttemptLetsALaterRedactionUnregisterAgain() async {
        registrar.redactContent(Data(#"{"transactionId":"ton:1"}"#.utf8), alertBody: "", activityId: "a")
        await registrar.waitUntilIdle()
        server.failsNextRegister = true
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await registrar.waitUntilIdle()
        registrar.contentChanged(nil, activityId: "a")

        registrar.redactContent(Data(#"{"transactionId":"ton:1"}"#.utf8), alertBody: "", activityId: "a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [.unregister("a"), .register("a", token: "01", tx: "ton:1"), .unregister("a")])
    }

    func test_redactionWhileAwaitingTheDeviceIdDoesNotSendOldContent() async throws {
        let gate = TestGate()
        let deviceIdRequested = TestSignal()
        var isAwaitingDeviceId = false
        let server = try XCTUnwrap(server)
        registrar = TransactionLiveActivityPushRegistrar(
            register: { try await server.register($0) },
            unregister: { try await server.unregister($0) },
            deviceId: {
                isAwaitingDeviceId = true
                deviceIdRequested.send()
                try await gate.wait()
                return server.deviceId
            },
            pushSubscription: { [] }
        )
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await waitUntil(deviceIdRequested) { isAwaitingDeviceId }

        let redacted = Data(#"{"transactionId":"ton:1","source":{"currency":"TON"}}"#.utf8)
        registrar.redactContent(redacted, alertBody: "TON", activityId: "a")
        await gate.open()
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.registrations.map(\.contentState), [redacted])
    }

    func test_anEndWaitsForTheRegistrationInFlightAndNothingRegistersAfterIt() async {
        let gate = TestGate()
        server.registerGate = gate
        registrar.tokenChanged(Data([1]), activityId: "a")
        registrar.contentChanged(content(), activityId: "a")
        await waitUntil(server.registerCalled) { server.calls.count == 1 }

        registrar.activityEnded("a")
        registrar.contentChanged(content(tx: "ton:2"), activityId: "a")
        registrar.tokenChanged(Data([2]), activityId: "a")
        await gate.open()
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [.register("a", token: "01", tx: "ton:1"), .unregister("a")])
    }

    func test_anActivityWithoutATokenEndsWithoutARequest() async {
        registrar.contentChanged(content(), activityId: "a")
        registrar.activityEnded("a")
        await registrar.waitUntilIdle()

        XCTAssertEqual(server.calls, [])
    }

    /// The server replaces the status, the title and the time, and clears the stage.
    func test_theStateTheServerSettlesDecodesInTheApp() throws {
        let pending = TransactionLiveActivityAttributes.ContentState(
            transactionId: "ton:1",
            chain: "ton",
            detail: nil,
            status: .pending,
            title: "Sending",
            updatedAt: Date(timeIntervalSinceReferenceDate: 100),
            source: .init(network: "TON", currency: "TON", amount: "10"),
            destination: nil,
            kind: .send,
            wallet: .init(name: "Wallet"),
            counterpartyAddress: "UQ…",
            stage: .init(index: 1, count: 3, title: "Sending"),
            perpsMarketId: nil,
            steps: 3,
            fiat: "$12.00",
            icon: "ton.png",
            queuedCount: 1
        )
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pending)) as? [String: Any])
        json["status"] = "confirmed"
        json["title"] = "Sent"
        json["updatedAt"] = 200.5
        json["stage"] = NSNull()

        let settled = try JSONDecoder().decode(
            TransactionLiveActivityAttributes.ContentState.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        XCTAssertEqual(settled.status, .confirmed)
        XCTAssertEqual(settled.title, "Sent")
        XCTAssertEqual(settled.updatedAt, Date(timeIntervalSinceReferenceDate: 200.5))
        XCTAssertNil(settled.stage)
        XCTAssertEqual(settled.source, pending.source)
        XCTAssertEqual(settled.wallet, pending.wallet)
        XCTAssertEqual(settled.steps, 3)
        XCTAssertEqual(settled.fiat, pending.fiat)
        XCTAssertEqual(settled.icon, pending.icon)
    }

    private func content(tx: String = "ton:1", alertBody: String = "10 TON") -> Content {
        Content(
            walletId: "wallet",
            contentState: Data(#"{"transactionId":"\#(tx)"}"#.utf8),
            finalTitles: .init(confirmed: "Sent", failed: "Failed", dropped: "Dropped"),
            alertBody: alertBody
        )
    }
}

@MainActor
private final class FakeServer {
    enum Call: Equatable {
        case register(String, token: String, tx: String)
        case unregister(String)
    }

    private(set) var calls: [Call] = []
    private(set) var registrations: [MultichainLiveActivityRegistration] = []
    let registerCalled = TestSignal()
    var registerGate: TestGate?
    var deviceId = "device-1"
    var pushSubscription: [String] = []
    var failsNextRegister = false
    var rejectsNextRegister = false
    var failsNextUnregister = false

    func register(_ registration: MultichainLiveActivityRegistration) async throws -> MultichainLiveActivityRegistrationResult {
        let state = try JSONSerialization.jsonObject(with: registration.contentState) as? [String: Any]
        registrations.append(registration)
        calls.append(.register(
            registration.activityId,
            token: registration.pushToken,
            tx: state?["transactionId"] as? String ?? ""
        ))
        registerCalled.send()
        try await registerGate?.wait()
        if failsNextRegister {
            failsNextRegister = false
            throw MultichainServiceError.apiError(message: "HTTP 503")
        }
        if rejectsNextRegister {
            rejectsNextRegister = false
            return .rejected(reason: "push_not_subscribed")
        }
        return .registered
    }

    func unregister(_ activityId: String) async throws {
        calls.append(.unregister(activityId))
        if failsNextUnregister {
            failsNextUnregister = false
            throw URLError(.notConnectedToInternet)
        }
    }
}
