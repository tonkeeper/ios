import Foundation
@testable import TKCore
import XCTest

final class AptabaseEventStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AptabaseEventStoreTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        super.tearDown()
    }

    func test_eventsSurviveAProcessThatNeverFlushed() async {
        let writer = makeStore()
        await writer.append(makeEvent(name: "first"))
        await writer.append(makeEvent(name: "second"))

        let reader = makeStore()
        let batch = await reader.peek(limit: 10)

        XCTAssertEqual(batch.events.map(\.eventName), ["first", "second"])
    }

    func test_loadSkipsALineTruncatedByACrashMidAppend() async throws {
        let writer = makeStore()
        await writer.append(makeEvent(name: "first"))
        await writer.append(makeEvent(name: "second"))
        await writer.append(makeEvent(name: "third"))

        let contents = try Data(contentsOf: fileURL)
        try contents.dropLast(20).write(to: fileURL)

        let reader = makeStore()
        let batch = await reader.peek(limit: 10)

        XCTAssertEqual(batch.events.map(\.eventName), ["first", "second"])
    }

    func test_loadDropsEventsTheServerWouldRefuseAsTooOld() async {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let writer = makeStore(currentDate: { base.addingTimeInterval(-24 * 60 * 60) })
        await writer.append(makeEvent(name: "expired", timestamp: base.addingTimeInterval(-24 * 60 * 60)))
        await writer.append(makeEvent(name: "fresh", timestamp: base))

        let reader = makeStore(currentDate: { base })
        let batch = await reader.peek(limit: 10)

        XCTAssertEqual(batch.events.map(\.eventName), ["fresh"])
    }

    func test_appendDropsTheOldestEventOnceTheLimitIsReached() async {
        let store = makeStore(maximumEventCount: 3)
        for index in 1 ... 5 {
            await store.append(makeEvent(name: "\(index)"))
        }

        let batch = await store.peek(limit: 10)
        let dropped = await store.droppedCount

        XCTAssertEqual(batch.events.map(\.eventName), ["3", "4", "5"])
        XCTAssertEqual(dropped, 2)
    }

    func test_removedEventsDoNotComeBackAfterAReload() async {
        let writer = makeStore()
        for index in 1 ... 3 {
            await writer.append(makeEvent(name: "\(index)"))
        }
        let batch = await writer.peek(limit: 2)
        await writer.remove(upTo: batch.upperBound)

        let reader = makeStore()
        let remaining = await reader.peek(limit: 10)

        XCTAssertEqual(remaining.events.map(\.eventName), ["3"])
    }

    /// Turning the feature flag off leaves the SDK branch, where nothing would ever send what is on
    /// disk — so it has to go rather than sit there until its TTL.
    func test_purgeRemovesAQueueLeftByAPreviousRun() async {
        let writer = makeStore()
        await writer.append(makeEvent(name: "first"))

        AptabaseEventStore.purge(configuration: AptabaseEventStore.Configuration(directory: directory))

        let reader = makeStore()
        let remaining = await reader.peek(limit: 10)
        XCTAssertTrue(remaining.events.isEmpty)
    }

    /// A full queue prunes its oldest entry while a batch is in flight; removing by count would then
    /// discard an event that was never sent.
    func test_removingASentBatchIgnoresEventsPrunedWhileItWasInFlight() async {
        let store = makeStore(maximumEventCount: 3)
        for index in 1 ... 3 {
            await store.append(makeEvent(name: "\(index)"))
        }
        let batch = await store.peek(limit: 2)

        await store.append(makeEvent(name: "4"))
        await store.remove(upTo: batch.upperBound)

        let remaining = await store.peek(limit: 10)
        XCTAssertEqual(remaining.events.map(\.eventName), ["3", "4"])
    }

    /// Storage is the only place a prop value is rebuilt from JSON, which carries no case tags, so an
    /// enum case the decoder cannot produce would silently change type on the way back.
    func test_propertyValuesKeepTheirCaseAcrossADiskRoundTrip() async {
        let props: [String: AptabasePropValue] = [
            "integer": .integer(42),
            "double": .double(1.5),
            "string": .string("value"),
            "boolean": .boolean(true),
        ]
        let writer = makeStore()
        await writer.append(makeEvent(name: "event", props: props))

        let reader = makeStore()
        let restored = await reader.peek(limit: 1).events.first
        XCTAssertEqual(restored?.props, props)
    }

    func test_aFloatArgumentIsStoredAsADoubleBecauseJsonCannotTellThemApart() {
        XCTAssertEqual(AptabasePropValue(analyticsValue: Float(1.5)), .double(1.5))
    }
}

private extension AptabaseEventStoreTests {
    var fileURL: URL {
        directory.appendingPathComponent("aptabase_events.jsonl")
    }

    func makeStore(
        maximumEventCount: Int = 1000,
        currentDate: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) }
    ) -> AptabaseEventStore {
        var configuration = AptabaseEventStore.Configuration(directory: directory)
        configuration.maximumEventCount = maximumEventCount
        return AptabaseEventStore(configuration: configuration, currentDate: currentDate)
    }

    func makeEvent(
        name: String,
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
        props: [String: AptabasePropValue]? = nil
    ) -> AptabaseEvent {
        AptabaseEvent(
            timestamp: timestamp,
            sessionId: "1700000000000000",
            eventName: name,
            systemProps: AptabaseEvent.SystemProps(
                isDebug: false,
                locale: "en",
                osName: "iOS",
                osVersion: "17.0",
                appVersion: "1.0",
                appBuildNumber: "1",
                sdkVersion: AptabaseEnvironment.sdkVersion,
                deviceModel: "iPhone15,2"
            ),
            props: props ?? ["index": .string(name)]
        )
    }
}
