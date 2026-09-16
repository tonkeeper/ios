import Foundation
@testable import KeeperCore
import TonAPI
import XCTest

final class WalletMigrationSendFailureMessageMappingTests: XCTestCase {
    func test_errorResponseBody_yieldsServerReason() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "error": "error 3: invalid seqno",
        ])
        let error = ErrorResponse.error(
            406,
            data,
            nil,
            NSError(domain: "WalletMigrationSendFailureMessageMappingTests", code: 406)
        )

        XCTAssertEqual(
            WalletMigrationError.sendFailureMessage(from: error),
            "error 3: invalid seqno"
        )
    }

    func test_undecodableErrorResponseBody_fallsBackToLocalizedDescription() {
        let error = ErrorResponse.error(500, Data("not json".utf8), nil, NSError(
            domain: "WalletMigrationSendFailureMessageMappingTests",
            code: 500
        ))

        XCTAssertEqual(
            WalletMigrationError.sendFailureMessage(from: error),
            error.localizedDescription
        )
    }

    func test_batteryApiError_keepsRelayMessage() {
        let error = BatteryAPI.ApiError.badStatus(
            status: 400,
            message: "user is disabled, try later"
        )

        XCTAssertEqual(
            WalletMigrationError.sendFailureMessage(from: error),
            "user is disabled, try later"
        )
    }
}
