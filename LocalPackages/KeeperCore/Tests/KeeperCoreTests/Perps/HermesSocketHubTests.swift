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
        hub.detach(id)
        XCTAssertTrue(sockets.all[1].isClosed)
    }

    func test_backoffResetsOnlyAfterConfirmedSubscription() async {
        let sockets = SocketFactory()
        let sleeps = Events()
        let hub = HermesSocketHub(
            sleep: { interval in
                guard interval <= 10 else { return await blockLongSleeps(interval) }
                sleeps.append("\(interval)")
            },
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

    private func makeHub(_ sockets: SocketFactory) -> HermesSocketHub {
        HermesSocketHub(sleep: blockLongSleeps, makeSocket: { sockets.make() })
    }

    private func listener(_ name: String, _ events: Events) -> HermesSocketListener {
        HermesSocketListener(
            onConnected: { events.append("\(name) connected") },
            onFrame: { events.append("\(name) frame \(String(decoding: $0, as: UTF8.self))") },
            onDisconnected: { events.append("\(name) disconnected") }
        )
    }

    private func watchCandles(_ hub: HermesSocketHub, _ events: Events) -> HermesCandleWatch {
        HermesCandleClient(hub: hub, sleep: blockLongSleeps).watch(
            feedId: feed,
            volumeFeedId: volumeFeed,
            onUpdate: { _ in events.append("update") },
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
    static func ack(_ reqid: Int64) -> String {
        #"{"channel":"subscribeCandleFeed","message":{"name":"subscribeCandleFeedResponse","reqid":\#(reqid)}}"#
    }

    static func error(_ reqid: Int64, code: String) -> String {
        #"{"channel":"subscribeCandleFeed","message":{"reqid":\#(reqid),"name":"errorResponse","payload":{"code":"\#(code)"}}}"#
    }

    static func push(_ feedId: String) -> String {
        #"{"channel":"candles","message":{"name":"candlesFeedMessage","payload":{"feedId":"\#(feedId)","data":{"ticker":"ETH/USD","resolution":"1m","start_ts":1700000000000,"candles":[]}}}}"#
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

private final class SocketFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var made: [FakeSocket] = []

    var all: [FakeSocket] {
        lock.lock()
        defer { lock.unlock() }
        return made
    }

    func make() -> any HermesSocket {
        let socket = FakeSocket()
        lock.lock()
        made.append(socket)
        lock.unlock()
        return socket
    }
}

private final class FakeSocket: HermesSocket, @unchecked Sendable {
    private let lock = NSLock()
    private var _sent: [String] = []
    private var inbox: [Result<URLSessionWebSocketTask.Message, any Error>] = []
    private var waiter: CheckedContinuation<URLSessionWebSocketTask.Message, any Error>?
    private var resumed = false
    private var closed = false

    var sent: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _sent
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
            lock.lock()
            _sent.append(resumed ? text : "unresumed \(text)")
            lock.unlock()
        }
        completionHandler(nil)
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
