import Foundation
@testable import KeeperCore
import XCTest

final class BatteryAPIErrorTests: XCTestCase {
    func test_cancellationClassification() {
        XCTAssertTrue(
            BatteryAPI.ApiError.unknown(underlying: CancellationError()).isCancellation
        )
        XCTAssertTrue(
            BatteryAPI.ApiError.unknown(
                underlying: URLError(.cancelled)
            ).isCancellation
        )
        XCTAssertFalse(
            BatteryAPI.ApiError.unknown(
                underlying: URLError(.timedOut)
            ).isCancellation
        )
    }
}
