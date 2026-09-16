import Foundation
@testable import TronSwiftAPI
import XCTest

final class TronTransactionInfoResponseTests: XCTestCase {
    func test_emptyObjectIsPending() {
        XCTAssertNil(TronTransactionInfoResponse.parse([:]))
    }

    func test_missingReceiptCountsAsSuccess() {
        let info = TronTransactionInfoResponse.parse([
            "id": "abc",
            "blockNumber": 10,
        ])
        XCTAssertEqual(info?.isSuccessful, true)
    }

    func test_explicitFailureIsNotSuccessful() {
        let info = TronTransactionInfoResponse.parse([
            "id": "abc",
            "blockNumber": 10,
            "receipt": ["result": "REVERT"],
        ])
        XCTAssertEqual(info?.isSuccessful, false)
        XCTAssertEqual(info?.receiptResult, "REVERT")
    }
}
