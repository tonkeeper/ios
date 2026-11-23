import Foundation
@testable import TKCore
@testable import TKServices
import XCTest

final class AnalyticsEventSequenceTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AnalyticsEventSequenceTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// Gaps in the sequence are how lost events are counted, so a race that skipped or repeated a
    /// number would show up as fake loss.
    func test_numbersStayUniqueAndContiguousWhenLoggedConcurrently() async {
        let sequence = makeSequence()

        let values = await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 500 {
                group.addTask { sequence.next() }
            }
            var values = Set<Int>()
            for await value in group {
                values.insert(value)
            }
            return values
        }

        XCTAssertEqual(values, Set(1 ... 500))
    }

    func test_counterResumesAfterARelaunch() {
        let before = makeSequence()
        _ = before.next()
        _ = before.next()

        let after = makeSequence()

        XCTAssertEqual(after.next(), 3)
    }

    func test_decorationCarriesTheSequenceTheTransportAndTheInstallScope() {
        let sequence = makeSequence()

        let args = AptabaseTransportProperty.decorate(["existing": "value"], sequence: sequence)

        XCTAssertEqual(args["existing"] as? String, "value")
        XCTAssertEqual(args[AptabaseTransportProperty.sequence] as? Int, 1)
        XCTAssertEqual(args[AptabaseTransportProperty.transport] as? String, "cache")
        XCTAssertEqual(args[AptabaseTransportProperty.installId] as? String, "install")
    }

    /// Seven `deposit_*` events carry a `Set<String>`, which cannot be encoded as a scalar and would
    /// cost the whole event.
    func test_normalizationFlattensValuesThatCannotBeEncoded() {
        let args = AptabaseTransportProperty.normalized([
            "set": Set(["p2p", "card"]),
            // What a `Set<String>` becomes once it has been through `Encodable.asDictionary()`, in the
            // two orders the same set can hash into.
            "array": NSArray(array: ["card", "p2p"]),
            "reversedArray": NSArray(array: ["p2p", "card"]),
            "string": "value",
            "number": 42,
            "flag": true,
            "unsupported": NSNull(),
        ])

        XCTAssertEqual(args["set"] as? String, "card,p2p")
        // One set has to reach the server as one value, or it splits a dimension in two.
        XCTAssertEqual(args["array"] as? String, "card,p2p")
        XCTAssertEqual(args["reversedArray"] as? String, "card,p2p")
        XCTAssertEqual(args["string"] as? String, "value")
        XCTAssertEqual(args["number"] as? Int, 42)
        XCTAssertEqual(args["flag"] as? Bool, true)
        XCTAssertNil(args["unsupported"])
    }
}

private extension AnalyticsEventSequenceTests {
    func makeSequence() -> AnalyticsEventSequence {
        AnalyticsEventSequence(installId: "install", userDefaults: userDefaults)
    }
}
