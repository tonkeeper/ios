import Foundation
@testable import KeeperCore
import TonAPI
import XCTest

final class MigrationPrepareConflictTests: XCTestCase {
    func test_insufficientTonConflictKeepsPreparedResponse() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "from": "from",
            "to": "to",
            "wallet_version": "v5R1",
            "transactions": [],
            "error": "insufficient TON for gas",
            "error_code": 50000,
            "details": [
                "required": 250_000_000,
                "available": 10_000_000,
            ],
        ])
        let error = ErrorResponse.error(
            409,
            data,
            nil,
            NSError(domain: "MigrationPrepareConflictTests", code: 409)
        )

        let response = try XCTUnwrap(
            MigrationPrepareResponseBody(insufficientTonError: error)
        )

        XCTAssertEqual(response.from, "from")
        XCTAssertEqual(response.to, "to")
        XCTAssertEqual(response.walletVersion, "v5R1")
        XCTAssertTrue(response.transactions.isEmpty)
        XCTAssertTrue(response.isInsufficientTonConflict)
        XCTAssertEqual(response.details?._required, 250_000_000)
        XCTAssertEqual(response.details?.available, 10_000_000)
    }

    func test_otherConflictDoesNotProducePreparedResponse() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "from": "from",
            "to": "to",
            "wallet_version": "v5R1",
            "transactions": [],
            "error": "another conflict",
            "error_code": 50001,
        ])
        let error = ErrorResponse.error(
            409,
            data,
            nil,
            NSError(domain: "MigrationPrepareConflictTests", code: 409)
        )

        XCTAssertNil(MigrationPrepareResponseBody(insufficientTonError: error))
    }
}
