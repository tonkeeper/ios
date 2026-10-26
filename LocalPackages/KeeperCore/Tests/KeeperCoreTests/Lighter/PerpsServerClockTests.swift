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
}
