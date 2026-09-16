import Foundation
@testable import TKCore
import TKFeatureFlags
import XCTest

final class AnalyticsLimitsTests: XCTestCase {
    func testKeysWithinTheLimitPassThroughUnchanged() {
        let args: [String: Any] = ["wallets_count": 3, "ff_ios_perps_enabled": "true"]

        let sanitized = sanitize(args)

        XCTAssertEqual(sanitized.keys.sorted(), args.keys.sorted())
    }

    func testOverLongKeyIsTruncatedAndTheRestOfTheEventSurvives() {
        let longKey = "ff_ios_is_swapkit_hard_switch_enabled_v2x"
        XCTAssertEqual(longKey.count, AnalyticsLimits.maximumPropertyKeyLength + 1)

        let sanitized = sanitize([longKey: "true", "wallets_count": 3])

        XCTAssertEqual(sanitized["wallets_count"] as? Int, 3)
        XCTAssertNil(sanitized[longKey])
        XCTAssertEqual(sanitized[String(longKey.prefix(AnalyticsLimits.maximumPropertyKeyLength))] as? String, "true")
    }

    func testBlankKeyIsDropped() {
        let sanitized = sanitize(["": "value", "  ": "value", "wallets_count": 3])

        XCTAssertEqual(sanitized.count, 1)
        XCTAssertEqual(sanitized["wallets_count"] as? Int, 3)
    }

    func testCollidingTruncationsResolveDeterministicallyToTheLowestKey() {
        let first = String(repeating: "a", count: 40) + "_first"
        let second = String(repeating: "a", count: 40) + "_second"

        for _ in 0 ..< 20 {
            let sanitized = sanitize([second: "second", first: "first"])
            XCTAssertEqual(sanitized[String(repeating: "a", count: 40)] as? String, "first")
        }
    }

    func testTruncationNeverDisplacesAnAlreadyValidKey() {
        let valid = String(repeating: "a", count: 40)
        let overLong = valid + "_suffix"

        let sanitized = sanitize([overLong: "truncated", valid: "valid"])

        XCTAssertEqual(sanitized[valid] as? String, "valid")
        XCTAssertEqual(sanitized.count, 1)
    }

    /// The Android regression that prompted this: `ff_android_is_swapkit_hard_switch_enabled` is 41
    /// characters, and Aptabase answered the whole `launch_app` payload with a 400.
    func testEveryFeatureFlagAnalyticsKeyFitsTheIngestionLimit() {
        let keys = Dictionary(uniqueKeysWithValues: FeatureFlag.allCases.map { ($0, true) })
            .analyticsParameters
            .keys

        XCTAssertFalse(keys.isEmpty)
        for key in keys {
            XCTAssertTrue(
                AnalyticsLimits.isValidPropertyKey(key),
                "\(key) is \(key.utf16.count) characters, over the \(AnalyticsLimits.maximumPropertyKeyLength) the ingestion API accepts"
            )
        }
    }

    func testEveryEventKeyNameFitsTheEventNameLimit() {
        for eventKey in EventKey.allCases {
            XCTAssertLessThanOrEqual(
                eventKey.key.utf16.count,
                AnalyticsLimits.maximumEventNameLength,
                "\(eventKey.key) is over the event name limit"
            )
        }
    }
}

private extension AnalyticsLimitsTests {
    /// Swallows the debug assertion the production path raises, so the repair itself stays testable.
    func sanitize(_ args: [String: Any]) -> [String: Any] {
        AnalyticsLimits.sanitizeKeys(args, reportViolation: { _ in })
    }
}
