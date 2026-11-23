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

    func test_messageRejection_keepsTheErrorKey() {
        let error = BatteryAPI.messageRejection(
            status: 402,
            message: "Not enough balance to send message",
            key: "err-gasless-balance"
        )

        guard case let .rejected(status, code, message) = error else {
            return XCTFail("expected rejected, got \(error)")
        }
        XCTAssertEqual(status, 402)
        XCTAssertEqual(code, "err-gasless-balance")
        XCTAssertEqual(message, "Not enough balance to send message")
    }

    func test_messageRejection_withoutAKeyStaysABadStatus() {
        for key in [nil, ""] {
            let error = BatteryAPI.messageRejection(status: 500, message: "internal error", key: key)

            guard case let .badStatus(status, message) = error else {
                return XCTFail("expected badStatus, got \(error)")
            }
            XCTAssertEqual(status, 500)
            XCTAssertEqual(message, "internal error")
        }
    }

    /// The authorization service recovers the device session only from a generic 401.
    func test_messageRejection_keepsA401Generic() {
        let error = BatteryAPI.messageRejection(status: 401, message: "unauthorized", key: "err-unauthorized")

        guard case .badStatus(401, _) = error else {
            return XCTFail("expected badStatus, got \(error)")
        }
    }
}
