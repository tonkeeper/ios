import Foundation
@testable import KeeperCore
import XCTest

final class HermesSocketHubTests: XCTestCase {
    func test_oneSocketServesAllListenersAndClosesAfterLast() async {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let first = UUID()
        let second = UUID()

        XCTAssertFalse(hub.attach(first, listener("a", events)))
        await waitUntil { events.all == ["a connected"] }
        XCTAssertTrue(hub.attach(second, listener("b", events)))
        let socket = sockets.all[0]
        socket.deliver("tick")
        await waitUntil { events.all.count == 3 }
        XCTAssertEqual(Set(events.all.dropFirst()), ["a frame tick", "b frame tick"])

        hub.detach(first)
        XCTAssertFalse(socket.isClosed)
        hub.detach(second)
        XCTAssertTrue(socket.isClosed)
        XCTAssertEqual(sockets.all.count, 1)
    }

    func test_sharedKeyIsUnsubscribedOnlyByLastHolder() async {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let first = UUID()
        let second = UUID()
        _ = hub.attach(first, listener("a", events))
        await waitUntil { events.contains("a connected") }
        let socket = sockets.all[0]

        XCTAssertNotNil(hub.subscribe(feed, by: first) { _ in Data("subscribe".utf8) })
        XCTAssertNotNil(hub.subscribe(feed, by: second) { _ in Data("subscribe".utf8) })
        hub.unsubscribe(feed, by: first) { _ in Data("unsubscribe".utf8) }
        hub.unsubscribe(feed, by: first) { _ in Data("unsubscribe".utf8) }
        XCTAssertEqual(socket.sent, ["subscribe", "subscribe"])
        hub.unsubscribe(feed, by: second) { _ in Data("unsubscribe".utf8) }
        XCTAssertEqual(socket.sent, ["subscribe", "subscribe", "unsubscribe"])
        hub.detach(first)
    }

    func test_droppedSocketReconnectsAndForgetsOldSubscriptions() async {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let id = UUID()
        _ = hub.attach(id, listener("a", events))
        await waitUntil { events.contains("a connected") }
        _ = hub.subscribe(feed, by: id) { _ in Data("subscribe".utf8) }

        sockets.all[0].drop()
        await waitUntil { events.all == ["a connected", "a disconnected", "a connected"] }
        hub.unsubscribe(feed, by: id) { _ in Data("unsubscribe".utf8) }
        XCTAssertEqual(sockets.all[1].sent, [])
        XCTAssertEqual(sockets.all.map(\.logins), [["jwt-1"], ["jwt-1"]])
        hub.detach(id)
        XCTAssertTrue(sockets.all[1].isClosed)
    }

    func test_listenersConnectOnlyAfterLoginResponse() async throws {
        let sockets = SocketFactory { _, _ in nil }
        let hub = makeHub(sockets)
        let events = Events()
        let id = UUID()
        XCTAssertFalse(hub.attach(id, listener("a", events)))
        await waitUntil { sockets.all.first?.logins == ["jwt-1"] }
        let socket = sockets.all[0]

        XCTAssertNil(hub.subscribe(feed, by: id) { _ in Data("subscribe".utf8) })
        socket.deliver(Frame.loggedIn(0))
        XCTAssertEqual(events.all, [])
        try socket.deliver(Frame.loggedIn(XCTUnwrap(socket.loginRequestId)))
        await waitUntil { events.all == ["a connected"] }

        XCTAssertNotNil(hub.subscribe(feed, by: id) { _ in Data("subscribe".utf8) })
        XCTAssertEqual(socket.sent, ["subscribe"])
        hub.detach(id)
    }

    func test_alreadyAuthenticatedCountsAsLoggedIn() async {
        let sockets = SocketFactory { _, reqid in Frame.loginError(reqid, code: "already.authenticated") }
        let hub = makeHub(sockets)
        let events = Events()
        let id = UUID()
        _ = hub.attach(id, listener("a", events))
        await waitUntil { events.all == ["a connected"] }

        XCTAssertEqual(sockets.all.count, 1)
        hub.detach(id)
    }

    func test_invalidCredentialsRenewsTokenAndReconnects() async {
        let deviceAuth = DeviceAuthFake()
        let sockets = SocketFactory { token, reqid in
            token == "jwt-1" ? Frame.loginError(reqid, code: "invalid.credentials") : Frame.loggedIn(reqid)
        }
        let hub = makeHub(sockets, deviceAuth)
        let events = Events()
        let id = UUID()
        _ = hub.attach(id, listener("a", events))
        await waitUntil { events.contains("a connected") }

        XCTAssertTrue(sockets.all[0].isClosed)
        XCTAssertEqual(sockets.all.map(\.logins), [["jwt-1"], ["jwt-2"]])
        let calls = await deviceAuth.calls
        XCTAssertEqual(calls, ["session", "recover jwt-1"])
        hub.detach(id)
    }

    func test_rejectedRenewedTokenIsNotRenewedAgain() async {
        let deviceAuth = DeviceAuthFake()
        let sockets = SocketFactory { _, reqid in Frame.loginError(reqid, code: "invalid.credentials") }
        let hub = makeHub(sockets, deviceAuth)
        let id = UUID()
        _ = hub.attach(id, listener("a", Events()))
        await waitUntil { sockets.all.count == 5 }

        XCTAssertEqual(sockets.all.map(\.logins), [["jwt-1"], ["jwt-2"], ["jwt-2"], ["jwt-2"], ["jwt-2"]])
        let calls = await deviceAuth.calls
        XCTAssertEqual(calls, ["session", "recover jwt-1", "session", "session", "session"])
        hub.detach(id)
    }

    func test_shortLivedTokenIsNotRenewedInALoop() async {
        let deviceAuth = DeviceAuthFake(lifetime: 60)
        let sockets = SocketFactory()
        let hub = makeHub(sockets, deviceAuth)
        let events = Events()
        let id = UUID()
        _ = hub.attach(id, listener("a", events))
        await waitUntil { events.contains("a connected") }
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sockets.all.map(\.logins), [["jwt-2"]])
        let calls = await deviceAuth.calls
        XCTAssertEqual(calls, ["session", "recover jwt-1"])
        hub.detach(id)
    }

    func test_tokenIsRenewedBeforeExpiryWithoutDisconnectingListeners() async {
        let deviceAuth = DeviceAuthFake()
        let sockets = SocketFactory()
        let gate = Gate()
        let renewals = Events()
        let hub = HermesSocketHub(
            sleep: { interval in
                guard interval > 600 else { return await blockLongSleeps(interval) }
                renewals.append("renewal")
                guard renewals.count("renewal") == 1 else { return await blockLongSleeps(interval) }
                await gate.wait()
            },
            deviceAuth: deviceAuth,
            makeSocket: { sockets.make() }
        )
        let events = Events()
        let id = UUID()
        _ = hub.attach(id, listener("a", events))
        await waitUntil { events.contains("a connected") }

        await gate.open()
        await waitUntil { events.count("a connected") == 2 }

        XCTAssertEqual(events.all, ["a connected", "a connected"])
        XCTAssertTrue(sockets.all[0].isClosed)
        XCTAssertEqual(sockets.all.map(\.logins), [["jwt-1"], ["jwt-2"]])
        let calls = await deviceAuth.calls
        XCTAssertEqual(calls, ["session", "recover jwt-1"])
        hub.detach(id)
    }

    func test_backoffResetsOnlyAfterConfirmedSubscription() async {
        let sockets = SocketFactory()
        let sleeps = Events()
        let hub = HermesSocketHub(
            sleep: { interval in
                guard interval <= 10 else { return await blockLongSleeps(interval) }
                sleeps.append("\(interval)")
            },
            deviceAuth: DeviceAuthFake(),
            makeSocket: { sockets.make() }
        )
        let events = Events()
        let id = UUID()
        _ = hub.attach(id, listener("a", events))
        await waitUntil { events.count("a connected") == 1 }

        sockets.all[0].drop()
        await waitUntil { events.count("a connected") == 2 }
        sockets.all[1].deliver("tick")
        await waitUntil { events.contains("a frame tick") }
        sockets.all[1].drop()
        await waitUntil { events.count("a connected") == 3 }
        hub.markHealthy()
        sockets.all[2].drop()
        await waitUntil { events.count("a connected") == 4 }

        XCTAssertEqual(sleeps.all, ["1.0", "2.0", "1.0"])
        hub.detach(id)
    }

    func test_attachWakesBackoffSleep() async {
        let sockets = SocketFactory()
        let hub = HermesSocketHub(
            sleep: { _ in try? await Task.sleep(nanoseconds: 3_600_000_000_000) },
            deviceAuth: DeviceAuthFake(),
            makeSocket: { sockets.make() }
        )
        let events = Events()
        let first = UUID()
        let second = UUID()
        _ = hub.attach(first, listener("a", events))
        await waitUntil { events.contains("a connected") }

        sockets.all[0].drop()
        await waitUntil { events.contains("a disconnected") }
        XCTAssertFalse(hub.attach(second, listener("b", events)))
        await waitUntil { events.contains("b connected") }

        XCTAssertEqual(sockets.all.count, 2)
        hub.detach(first)
        hub.detach(second)
    }

    func test_staleConnectAttemptIsDroppedAfterReattach() async {
        let sockets = SocketFactory()
        let gate = Gate()
        let attempts = Events()
        let hub = HermesSocketHub(
            sleep: blockLongSleeps,
            deviceAuth: DeviceAuthFake(),
            makeSocket: {
                attempts.append("connect")
                if attempts.count("connect") == 1 {
                    await gate.wait()
                }
                return sockets.make()
            }
        )
        let events = Events()
        let first = UUID()
        let second = UUID()
        _ = hub.attach(first, listener("a", events))
        await waitUntil { attempts.count("connect") == 1 }
        hub.detach(first)
        _ = hub.attach(second, listener("b", events))
        await waitUntil { events.all == ["b connected"] }

        await gate.open()
        await waitUntil { sockets.all.count == 2 && sockets.all[1].isClosed }
        sockets.all[0].deliver("tick")
        await waitUntil { events.all.count == 2 }

        XCTAssertEqual(events.all, ["b connected", "b frame tick"])
        XCTAssertFalse(sockets.all[0].isClosed)
        hub.detach(second)
    }

    func test_clientsUnsubscribeOnCancelWhileSharedSocketStaysOpen() async {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let other = UUID()
        _ = hub.attach(other, listener("other", events))
        await waitUntil { events.contains("other connected") }
        let socket = sockets.all[0]

        let prices = HermesMarkPricesClient(hub: hub, sleep: blockLongSleeps)
            .watch(onUpdate: { _ in }, onReconnecting: {}, onRejected: {})
        prices.setTickers(["ETH/USD"])
        let candles = watchCandles(hub, events)
        await waitUntil { socket.channels.filter { $0.hasPrefix("subscribe") }.count == 3 }

        prices.cancel()
        candles.cancel()
        await waitUntil { socket.channels.filter { $0.hasPrefix("unsubscribe") }.count == 3 }
        XCTAssertFalse(socket.isClosed)
        hub.detach(other)
    }

    func test_candlePushesAreRoutedByFeedIdAndHeldUntilAck() async throws {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let candles = watchCandles(hub, events)
        await waitUntil { sockets.all.first?.sentCount("subscribeCandleFeed") == 2 }
        let socket = sockets.all[0]

        socket.deliver(Frame.push(volumeFeed))
        socket.deliver(Frame.push(feed))
        socket.deliver(Frame.push("BTC/USD/1m"))
        try socket.deliver(Frame.ack(XCTUnwrap(socket.requestId("subscribeCandleFeed", feedId: feed))))
        socket.deliver(Frame.push(volumeFeed))
        await waitUntil { events.count("volume") == 2 }

        XCTAssertEqual(events.all, ["volume", "subscribed", "update", "volume"])
        candles.cancel()
    }

    func test_candlePushesHeldUntilAckKeepOnlyTheLatestFiveThousandCandles() async throws {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let updates = Events()
        let candles = watchCandles(hub, events, updates: updates)
        await waitUntil { sockets.all.first?.sentCount("subscribeCandleFeed") == 2 }
        let socket = sockets.all[0]

        for startTs in 1 ... 7 {
            socket.deliver(Frame.push(feed, startTs: Int64(startTs), candles: 1000))
        }
        socket.deliver(Frame.push(feed, startTs: 8, candles: 5001))
        try socket.deliver(Frame.ack(XCTUnwrap(socket.requestId("subscribeCandleFeed", feedId: feed))))
        await waitUntil { events.count("update") == 5 }

        XCTAssertEqual(updates.all, ["3", "4", "5", "6", "7"])
        candles.cancel()
    }

    func test_emptyCandlePushesHeldUntilAckAreCappedToo() async throws {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let updates = Events()
        let candles = watchCandles(hub, events, updates: updates)
        await waitUntil { sockets.all.first?.sentCount("subscribeCandleFeed") == 2 }
        let socket = sockets.all[0]

        for startTs in 1 ... 5010 {
            socket.deliver(Frame.push(feed, startTs: Int64(startTs)))
        }
        try socket.deliver(Frame.ack(XCTUnwrap(socket.requestId("subscribeCandleFeed", feedId: feed))))
        await waitUntil(timeout: 10) { events.count("update") == 5000 }

        XCTAssertEqual(updates.all.first, "11")
        XCTAssertEqual(updates.all.last, "5010")
        candles.cancel()
    }

    func test_candleRetriesItsFailedSubscriptionWithoutDroppingSocket() async throws {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        let candles = watchCandles(hub, events)
        await waitUntil { sockets.all.first?.sentCount("subscribeCandleFeed") == 2 }
        let socket = sockets.all[0]

        try socket.deliver(Frame.error(XCTUnwrap(socket.requestId("subscribeCandleFeed", feedId: feed)), code: "unavailable"))
        await waitUntil { socket.sentCount("subscribeCandleFeed", feedId: feed) == 2 }
        try socket.deliver(Frame.ack(XCTUnwrap(socket.requestId("subscribeCandleFeed", feedId: feed))))
        await waitUntil { events.contains("subscribed") }

        XCTAssertEqual(sockets.all.count, 1)
        XCTAssertFalse(socket.isClosed)
        XCTAssertEqual(events.all, ["subscribed"])
        candles.cancel()
        await waitUntil { socket.isClosed }
    }

    func test_rejectedCandleFeedDetachesFromInsideFrameFanOut() async throws {
        let sockets = SocketFactory()
        let hub = makeHub(sockets)
        let events = Events()
        _ = watchCandles(hub, events)
        await waitUntil { sockets.all.first?.sentCount("subscribeCandleFeed") == 2 }
        let socket = sockets.all[0]

        try socket.deliver(Frame.error(XCTUnwrap(socket.requestId("subscribeCandleFeed", feedId: feed)), code: "not.found"))
        await waitUntil { socket.isClosed }

        XCTAssertEqual(events.all, ["rejected"])
        XCTAssertEqual(socket.sentCount("unsubscribeCandleFeed"), 2)
    }

    private func makeHub(_ sockets: SocketFactory, _ deviceAuth: DeviceAuthFake = DeviceAuthFake()) -> HermesSocketHub {
        HermesSocketHub(sleep: blockLongSleeps, deviceAuth: deviceAuth, makeSocket: { sockets.make() })
    }

    private func listener(_ name: String, _ events: Events) -> HermesSocketListener {
        HermesSocketListener(
            onConnected: { events.append("\(name) connected") },
            onFrame: { events.append("\(name) frame \(String(decoding: $0, as: UTF8.self))") },
            onDisconnected: { events.append("\(name) disconnected") }
        )
    }

    private func watchCandles(_ hub: HermesSocketHub, _ events: Events, updates: Events? = nil) -> HermesCandleWatch {
        HermesCandleClient(hub: hub, sleep: blockLongSleeps).watch(
            feedId: feed,
            volumeFeedId: volumeFeed,
            onUpdate: { response in
                events.append("update")
                updates?.append("\(response.start_ts)")
            },
            onVolumeUpdate: { _ in events.append("volume") },
            onSubscribed: { events.append("subscribed") },
            onReconnecting: { events.append("reconnecting") },
            onRejected: { events.append("rejected") }
        )
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }
}

private let feed = "ETH/USD/1m"
private let volumeFeed = "ETH/USD/PERP_TRADE/1m"

private let blockLongSleeps: @Sendable (TimeInterval) async -> Void = { interval in
    guard interval > 10 else { return }
    try? await Task.sleep(nanoseconds: 3_600_000_000_000)
}

private enum Frame {
    static func loggedIn(_ reqid: Int64) -> String {
        #"{"channel":"login","message":{"name":"loginResponse","reqid":\#(reqid)}}"#
    }

    static func loginError(_ reqid: Int64, code: String) -> String {
        #"{"channel":"login","message":{"reqid":\#(reqid),"name":"errorResponse","payload":{"code":"\#(code)"}}}"#
    }

    static func ack(_ reqid: Int64) -> String {
        #"{"channel":"subscribeCandleFeed","message":{"name":"subscribeCandleFeedResponse","reqid":\#(reqid)}}"#
    }

    static func error(_ reqid: Int64, code: String) -> String {
        #"{"channel":"subscribeCandleFeed","message":{"reqid":\#(reqid),"name":"errorResponse","payload":{"code":"\#(code)"}}}"#
    }

    static func push(_ feedId: String, startTs: Int64 = 1_700_000_000_000, candles: Int = 0) -> String {
        let candles = Array(repeating: #"{"o":"1","h":"1","l":"1","c":"1"}"#, count: candles).joined(separator: ",")
        return #"{"channel":"candles","message":{"name":"candlesFeedMessage","payload":{"feedId":"\#(feedId)","data":{"ticker":"ETH/USD","resolution":"1m","start_ts":\#(startTs),"candles":[\#(candles)]}}}}"#
    }
}

private final class Events: @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return log
    }

    func append(_ event: String) {
        lock.lock()
        log.append(event)
        lock.unlock()
    }

    func contains(_ event: String) -> Bool {
        all.contains(event)
    }

    func count(_ event: String) -> Int {
        all.filter { $0 == event }.count
    }
}

private actor Gate {
    private var opened = false
    private var waiter: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        opened = true
        waiter?.resume()
        waiter = nil
    }
}

private actor DeviceAuthFake: DeviceAuthProviding {
    private(set) var calls: [String] = []
    private let lifetime: TimeInterval
    private var current: DeviceAuthSession?
    private var issued = 0

    init(lifetime: TimeInterval = 15 * 60) {
        self.lifetime = lifetime
    }

    func session() -> DeviceAuthSession {
        calls.append("session")
        return current ?? issue()
    }

    func recoverSession(invalidating accessToken: String) -> DeviceAuthSession {
        calls.append("recover \(accessToken)")
        if let current, current.accessToken != accessToken {
            return current
        }
        return issue()
    }

    func isDeviceKnown() -> Bool {
        true
    }

    private func issue() -> DeviceAuthSession {
        issued += 1
        let session = DeviceAuthSession(
            deviceId: "device",
            accessToken: "jwt-\(issued)",
            expiresAt: Date().addingTimeInterval(lifetime)
        )
        current = session
        return session
    }
}

private final class SocketFactory: @unchecked Sendable {
    private let lock = NSLock()
    private let loginReply: @Sendable (_ token: String, _ reqid: Int64) -> String?
    private var made: [FakeSocket] = []

    init(loginReply: @escaping @Sendable (_ token: String, _ reqid: Int64) -> String? = { Frame.loggedIn($1) }) {
        self.loginReply = loginReply
    }

    var all: [FakeSocket] {
        lock.lock()
        defer { lock.unlock() }
        return made
    }

    func make() -> any HermesSocket {
        let socket = FakeSocket(loginReply: loginReply)
        lock.lock()
        made.append(socket)
        lock.unlock()
        return socket
    }
}

private final class FakeSocket: HermesSocket, @unchecked Sendable {
    private let lock = NSLock()
    private let loginReply: @Sendable (_ token: String, _ reqid: Int64) -> String?
    private var _sent: [String] = []
    private var _logins: [String] = []
    private var _loginRequestId: Int64?
    private var inbox: [Result<URLSessionWebSocketTask.Message, any Error>] = []
    private var waiter: CheckedContinuation<URLSessionWebSocketTask.Message, any Error>?
    private var resumed = false
    private var closed = false

    init(loginReply: @escaping @Sendable (_ token: String, _ reqid: Int64) -> String?) {
        self.loginReply = loginReply
    }

    var sent: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _sent
    }

    var logins: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _logins
    }

    var loginRequestId: Int64? {
        lock.lock()
        defer { lock.unlock() }
        return _loginRequestId
    }

    var isClosed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return closed
    }

    var channels: [String] {
        frames.compactMap { $0["channel"] as? String }
    }

    func requestId(_ channel: String, feedId: String) -> Int64? {
        frames(channel, feedId: feedId).last.flatMap { ($0["message"] as? [String: Any])?["reqid"] as? NSNumber }?.int64Value
    }

    func sentCount(_ channel: String, feedId: String? = nil) -> Int {
        frames(channel, feedId: feedId).count
    }

    func deliver(_ text: String) {
        push(.success(.string(text)))
    }

    func drop() {
        push(.failure(URLError(.networkConnectionLost)))
    }

    func resume() {
        lock.lock()
        resumed = true
        lock.unlock()
    }

    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        if case let .string(text) = message {
            if let login = Self.login(from: text) {
                lock.lock()
                _logins.append(login.token)
                _loginRequestId = login.reqid
                lock.unlock()
                if let reply = loginReply(login.token, login.reqid) {
                    deliver(reply)
                }
            } else {
                lock.lock()
                _sent.append(resumed ? text : "unresumed \(text)")
                lock.unlock()
            }
        }
        completionHandler(nil)
    }

    private static func login(from text: String) -> (token: String, reqid: Int64)? {
        guard let frame = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              frame["channel"] as? String == "login",
              let message = frame["message"] as? [String: Any],
              let reqid = (message["reqid"] as? NSNumber)?.int64Value,
              let token = (message["payload"] as? [String: Any])?["token"] as? String
        else { return nil }
        return (token, reqid)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            let next: Result<URLSessionWebSocketTask.Message, any Error>?
            if !inbox.isEmpty {
                next = inbox.removeFirst()
            } else if closed {
                next = .failure(URLError(.cancelled))
            } else {
                next = nil
                waiter = continuation
            }
            lock.unlock()
            if let next {
                continuation.resume(with: next)
            }
        }
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        lock.lock()
        closed = true
        let waiter = waiter
        self.waiter = nil
        lock.unlock()
        waiter?.resume(throwing: URLError(.cancelled))
    }

    private var frames: [[String: Any]] {
        sent.compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
    }

    private func frames(_ channel: String, feedId: String?) -> [[String: Any]] {
        frames.filter { frame in
            let payload = (frame["message"] as? [String: Any])?["payload"] as? [String: Any]
            return frame["channel"] as? String == channel && (feedId == nil || payload?["feedId"] as? String == feedId)
        }
    }

    private func push(_ result: Result<URLSessionWebSocketTask.Message, any Error>) {
        lock.lock()
        let waiter = waiter
        self.waiter = nil
        if waiter == nil {
            inbox.append(result)
        }
        lock.unlock()
        waiter?.resume(with: result)
    }
}
