import Foundation
@testable import TKCore
import XCTest

private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

final class AptabaseQueueClientTests: XCTestCase {
    private var directory: URL!
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AptabaseQueueClientTests-\(UUID().uuidString)")
        suiteName = "AptabaseQueueClientTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        userDefaults.removePersistentDomain(forName: suiteName)
        directory = nil
        suiteName = nil
        userDefaults = nil
        super.tearDown()
    }

    /// The reason events cross into the actor through an `AsyncStream` instead of one detached
    /// `Task` each.
    func test_loggedEventsReachTheStoreInTheOrderTheyWereLogged() async throws {
        let subject = makeSubject(responses: [.status(429)])

        for index in 0 ..< 30 {
            subject.service.logEvent(name: "event_\(index)", args: [:])
        }
        try await waitForPending(subject.client, count: 30)

        let batch = await subject.store.peek(limit: 30)
        XCTAssertEqual(batch.events.map(\.eventName), (0 ..< 30).map { "event_\($0)" })
    }

    func test_flushNeverSendsMoreEventsThanTheServerAccepts() async throws {
        let subject = makeSubject(responses: [.status(200)])

        for index in 0 ..< 30 {
            subject.service.logEvent(name: "event_\(index)", args: [:])
        }
        try await drainQueue(subject.client, through: subject.session, expectedAttemptedCount: 30)

        let batchSizes = try await subject.session.requests.map { try batchSize(of: $0) }
        XCTAssertFalse(batchSizes.isEmpty)
        XCTAssertTrue(batchSizes.allSatisfy { $0 <= AptabaseDispatcher.maximumBatchSize })
        XCTAssertEqual(batchSizes.reduce(0, +), 30)
        let pending = await subject.client.pendingCount()
        XCTAssertEqual(pending, 0)
    }

    /// Backgrounding has to flush events that were logged microseconds earlier and are still on their
    /// way to the store — the process may not survive to the next launch.
    func test_suspendingFlushesEventsThatHaveNotReachedTheStoreYet() async throws {
        let parts = makeClient(responses: [.status(200)])
        let inputs = await start(parts.client)
        defer { inputs.finish() }

        for index in 0 ..< 10 {
            inputs.yield(.event(makePendingEvent(name: "event_\(index)")))
        }
        await withCheckedContinuation { finished in
            inputs.yield(.suspended { finished.resume() })
        }

        let sent = try await parts.session.requests.map { try batchSize(of: $0) }.reduce(0, +)
        XCTAssertEqual(sent, 10)
        let pending = await parts.client.pendingCount()
        XCTAssertEqual(pending, 0)
    }

    func test_rateLimitedBatchStaysOnDisk() async throws {
        let subject = makeSubject(responses: [.status(429)])

        subject.service.logEvent(name: "event", args: [:])
        try await waitForPending(subject.client, count: 1)
        await subject.client.flush()

        let pending = await subject.client.pendingCount()
        XCTAssertEqual(pending, 1)
    }

    func test_refusedBatchLeavesTheQueue() async throws {
        let subject = makeSubject(responses: [.status(400)])

        subject.service.logEvent(name: "event", args: [:])
        try await drainQueue(subject.client, through: subject.session, expectedAttemptedCount: 1)

        let pending = await subject.client.pendingCount()
        XCTAssertEqual(pending, 0)
    }

    /// `/api/v0/events` filters the events it cannot accept and still answers 200, so a 4xx condemns
    /// the request as a whole. Resending one event at a time keeps the ones the server would have taken.
    func test_refusedBatchIsResentOneEventAtATime() async throws {
        let subject = makeSubject(responses: [.status(400), .status(200), .status(400), .status(200)])

        for index in 0 ..< 3 {
            subject.service.logEvent(name: "event_\(index)", args: [:])
        }
        try await waitForPending(subject.client, count: 3)
        await subject.client.flush()

        let requests = await subject.session.requests
        let batchSizes = try requests.map { try batchSize(of: $0) }
        XCTAssertEqual(batchSizes, [3, 1, 1, 1])
        let resent = try requests.dropFirst().flatMap { try eventNames(of: $0) }
        XCTAssertEqual(resent, ["event_0", "event_1", "event_2"])
        let pending = await subject.client.pendingCount()
        XCTAssertEqual(pending, 0)
    }

    /// The connection can drop part-way through the individual resend. What the server already took is
    /// off the queue; what was never attempted stays for the next flush.
    func test_transportFailureDuringTheIndividualResendKeepsWhatWasNotAttempted() async throws {
        let subject = makeSubject(responses: [.status(400), .status(200), .transportFailure])

        for index in 0 ..< 3 {
            subject.service.logEvent(name: "event_\(index)", args: [:])
        }
        try await waitForPending(subject.client, count: 3)
        await subject.client.flush()

        let remaining = await subject.store.peek(limit: 3).events.map(\.eventName)
        XCTAssertEqual(remaining, ["event_1", "event_2"])
    }

    /// Without this the queue sits out the whole backoff — up to five minutes — with connectivity
    /// already back. Pairs with `test_backoffHoldsTheNextFlushAfterATransportFailure`.
    func test_networkAvailableClearsTheBackoffAndFlushes() async throws {
        let parts = makeClient(responses: [.transportFailure, .status(200)])
        let inputs = await start(parts.client)
        defer { inputs.finish() }

        inputs.yield(.event(makePendingEvent(name: "event")))
        try await waitForPending(parts.client, count: 1)
        await parts.client.flush()
        await parts.client.flush()
        let heldRequestCount = await parts.session.requests.count
        XCTAssertEqual(heldRequestCount, 1)

        inputs.yield(.networkAvailable)

        try await waitForPending(parts.client, count: 0)
        let requestCount = await parts.session.requests.count
        XCTAssertEqual(requestCount, 2)
    }

    func test_backoffHoldsTheNextFlushAfterATransportFailure() async throws {
        let subject = makeSubject(responses: [.transportFailure])

        subject.service.logEvent(name: "event", args: [:])
        try await waitForPending(subject.client, count: 1)
        await subject.client.flush()
        await subject.client.flush()

        let requestCount = await subject.session.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    /// Rotation follows the timestamp carried by the event, so the events are handed over directly
    /// rather than through a clock the whole client would have to share.
    func test_sessionIdRotatesOnlyAfterAnHourOfInactivity() async throws {
        let parts = makeClient(responses: [.status(429)])
        let inputs = await start(parts.client)
        defer { inputs.finish() }

        inputs.yield(.event(makePendingEvent(name: "first")))
        inputs.yield(.event(makePendingEvent(name: "second", at: referenceDate.addingTimeInterval(30 * 60))))
        inputs.yield(.event(makePendingEvent(name: "third", at: referenceDate.addingTimeInterval(3 * 60 * 60))))
        try await waitForPending(parts.client, count: 3)

        let events = await parts.store.peek(limit: 3).events
        XCTAssertEqual(events[0].sessionId, events[1].sessionId)
        XCTAssertNotEqual(events[1].sessionId, events[2].sessionId)
    }

    /// The SDK discards the whole event when one property has an unsupported type.
    func test_unsupportedPropertyDiscardsOnlyThatProperty() async throws {
        let subject = makeSubject(responses: [.status(429)])

        subject.service.logEvent(name: "event", args: ["kept": "value", "dropped": Data()])
        try await waitForPending(subject.client, count: 1)

        let props = await subject.store.peek(limit: 1).events.first?.props
        XCTAssertEqual(props?["kept"], .string("value"))
        XCTAssertNil(props?["dropped"])
        XCTAssertEqual(props?[AptabaseTransportProperty.transport], .string("cache"))
        XCTAssertEqual(props?[AptabaseTransportProperty.sequence], .integer(1))
    }

    /// `availableOptions` is the one list-valued schema field and it is `uniqueItems`, so it reaches the
    /// transport as a JSON-encoded `Set<String>` — an order that rides on the per-process hash seed.
    /// Sorting is what keeps one set of options from serialising differently on every launch, so the
    /// input order here is deliberately not the sorted one: an in-place join would keep `usdt` first.
    func test_stringCollectionPropertyIsSortedRatherThanJoinedInPlace() {
        let fromJSON = AptabaseTransportProperty.normalized(["available_options": ["usdt", "card", "ton"]])
        XCTAssertEqual(fromJSON["available_options"] as? String, "card,ton,usdt")

        // The legacy `args` path can hand over a real `Set`, which never crosses `JSONEncoder`.
        let fromSet = AptabaseTransportProperty.normalized(["available_options": Set(["usdt", "card", "ton"])])
        XCTAssertEqual(fromSet["available_options"] as? String, "card,ton,usdt")
    }

    /// The shape the schema field actually arrives in: `JSONEncoder` turns the set into an array, which
    /// has to survive as a string collection rather than be discarded as an unsupported type.
    func test_jsonEncodedSetReachesTheStoreAsAStringCollection() async throws {
        let subject = makeSubject(responses: [.status(429)])
        let encoded = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(["available_options": Set(["usdt", "card", "ton"])])
        ) as? [String: Any]
        let options = try XCTUnwrap(encoded?["available_options"])

        subject.service.logEvent(name: "event", args: ["available_options": options])
        try await waitForPending(subject.client, count: 1)

        let props = await subject.store.peek(limit: 1).events.first?.props
        XCTAssertEqual(props?["available_options"], .string("card,ton,usdt"))
    }
}

private extension AptabaseQueueClientTests {
    struct Subject {
        let service: AptabaseQueuedService
        let client: AptabaseQueueClient
        let store: AptabaseEventStore
        let session: StubAptabaseURLSession
    }

    func makeSubject(responses: [StubAptabaseURLSession.Response]) -> Subject {
        let parts = makeClient(responses: responses)
        let service = AptabaseQueuedService(
            client: parts.client,
            sequence: AnalyticsEventSequence(installId: "install", userDefaults: userDefaults),
            cohortSource: .remote,
            currentDate: { referenceDate }
        )
        return Subject(service: service, client: parts.client, store: parts.store, session: parts.session)
    }

    func makeClient(
        responses: [StubAptabaseURLSession.Response]
    ) -> (client: AptabaseQueueClient, store: AptabaseEventStore, session: StubAptabaseURLSession) {
        let environment = AptabaseEnvironment(
            isDebug: false,
            osName: "iOS",
            osVersion: "17.0",
            locale: "en",
            appVersion: "1.0",
            appBuildNumber: "1",
            deviceModel: "iPhone15,2"
        )
        let store = AptabaseEventStore(
            configuration: AptabaseEventStore.Configuration(directory: directory),
            currentDate: { referenceDate }
        )
        let session = StubAptabaseURLSession(responses: responses)
        let client = AptabaseQueueClient(
            store: store,
            dispatcher: AptabaseDispatcher(
                endpointProvider: { "https://analytics.example.com" },
                appKey: "A-SH-0000000000",
                environment: environment,
                session: session
            ),
            environment: environment,
            // Long enough that only the explicit flushes in these tests hit the network.
            flushInterval: 3600,
            currentDate: { referenceDate }
        )
        return (client, store, session)
    }

    /// Drives a client directly, for the cases that need to place something other than an event on the
    /// input stream.
    func start(_ client: AptabaseQueueClient) async -> AsyncStream<AptabaseQueueInput>.Continuation {
        var continuation: AsyncStream<AptabaseQueueInput>.Continuation!
        let inputs = AsyncStream<AptabaseQueueInput>(bufferingPolicy: .unbounded) { continuation = $0 }
        await client.start(consuming: inputs)
        return continuation
    }

    func makePendingEvent(name: String, at timestamp: Date = referenceDate) -> AptabasePendingEvent {
        AptabasePendingEvent(name: name, props: [:], timestamp: timestamp)
    }

    func waitForPending(
        _ client: AptabaseQueueClient,
        count: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0 ..< 400 {
            if await client.pendingCount() == count { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("timed out waiting for \(count) queued events", file: file, line: line)
    }

    func drainQueue(
        _ client: AptabaseQueueClient,
        through session: StubAptabaseURLSession,
        expectedAttemptedCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0 ..< 400 {
            await client.flush()
            let requests = await session.requests
            let attemptedCount = try requests.map { try batchSize(of: $0) }.reduce(0, +)
            if attemptedCount == expectedAttemptedCount,
               await client.pendingCount() == 0
            {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("timed out draining \(expectedAttemptedCount) queued events", file: file, line: line)
    }

    func eventNames(of request: URLRequest) throws -> [String] {
        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        return payload.compactMap { $0["eventName"] as? String }
    }

    func batchSize(of request: URLRequest) throws -> Int {
        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        return payload.count
    }
}
