import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import XCTest

final class PerpsServerClockTests: XCTestCase {
    func testTheResponseDateHeaderSetsTheServerOffset() async throws {
        let clock = PerpsServerClock()
        let middleware = PerpsServerClockMiddleware(clock: clock)
        let serverDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-02T12:36:38Z"))

        _ = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/"),
            body: nil,
            baseURL: XCTUnwrap(URL(string: "https://example.com")),
            operationID: "getTruncatedOrderBook"
        ) { _, _, _ in
            (HTTPResponse(status: .ok, headerFields: [.date: "Fri, 02 Oct 2026 12:36:38 GMT"]), nil)
        }

        let offset = try XCTUnwrap(clock.serverOffsetMs)
        let expected = Int64(serverDate.timeIntervalSinceNow * 1000)
        XCTAssertLessThan(abs(offset - expected), 2000)
    }

    func testTheServerTimeFollowsADateHeaderWithinAMinute() {
        for skew: TimeInterval in [-30, 30] {
            let clock = PerpsServerClock()
            let deviceNow = PerpsPlannerMapping.nowUnixMs()
            clock.record(serverDate: Date().addingTimeInterval(skew))

            let serverNow = clock.trustedServerNowUnixMs(deviceNowUnixMs: deviceNow)

            XCTAssertEqual(Double(serverNow ?? 0), Double(deviceNow) + skew * 1000, accuracy: 2000, "skew \(skew)")
        }
    }

    func testADateHeaderMoreThanAMinuteOffIsNotTakenForTheServerTime() {
        for skew: TimeInterval in [-90, 90, 365 * 86400] {
            let clock = PerpsServerClock()
            clock.record(serverDate: Date().addingTimeInterval(skew))

            XCTAssertNil(clock.trustedServerNowUnixMs(deviceNowUnixMs: PerpsPlannerMapping.nowUnixMs()), "skew \(skew)")
        }
    }

    func testSigningFollowsADateHeaderWithinAMinute() {
        for skew: TimeInterval in [-59, -30, 30, 59] {
            let clock = PerpsServerClock()
            let deviceNow = PerpsPlannerMapping.nowUnixMs()
            clock.record(serverDate: Date().addingTimeInterval(skew))

            let signingNow = clock.signingNowUnixMs(deviceNowUnixMs: deviceNow)

            XCTAssertEqual(Double(signingNow), Double(deviceNow) + skew * 1000, accuracy: 2000, "skew \(skew)")
        }
    }

    func testSigningStaysOnTheDeviceClockWhenTheDateHeaderIsMoreThanAMinuteOff() {
        for skew: TimeInterval in [-365 * 86400, -61, 61, 365 * 86400] {
            let clock = PerpsServerClock()
            let deviceNow = PerpsPlannerMapping.nowUnixMs()
            clock.record(serverDate: Date().addingTimeInterval(skew))

            XCTAssertEqual(clock.signingNowUnixMs(deviceNowUnixMs: deviceNow), deviceNow, "skew \(skew)")
        }
    }

    func testWithoutADateHeaderSigningIsOnTheDeviceClock() {
        let deviceNow = PerpsPlannerMapping.nowUnixMs()

        XCTAssertEqual(PerpsServerClock().signingNowUnixMs(deviceNowUnixMs: deviceNow), deviceNow)
    }

    func testWithoutADateHeaderTheServerTimeIsTheDeviceTime() {
        let deviceNow = PerpsPlannerMapping.nowUnixMs()

        XCTAssertEqual(PerpsServerClock().trustedServerNowUnixMs(deviceNowUnixMs: deviceNow), deviceNow)
    }
}
