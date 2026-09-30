@testable import KeeperCore
import XCTest

final class TronUSDTAPIMergeTests: XCTestCase {
    func test_mergeSortsDescendingByTimestampRegardlessOfInputOrder() {
        let merged = TronUSDTAPI.mergeDeduplicatingByTxID(
            [transaction(txID: "a", timestamp: 100)],
            [transaction(txID: "b", timestamp: 300), transaction(txID: "c", timestamp: 200)]
        )

        XCTAssertEqual(merged.map(\.txID), ["b", "c", "a"])
    }

    func test_mergeDropsDuplicateTxIDsKeepingTheFirstSource() {
        let merged = TronUSDTAPI.mergeDeduplicatingByTxID(
            [transaction(txID: "dup", timestamp: 100, amount: "1")],
            [transaction(txID: "dup", timestamp: 100, amount: "2")]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.amount, 1)
    }

    func test_mergeIsStableAcrossRepeatedCallsUnlikeSetBasedUnion() {
        let lhs = (0 ..< 20).map { transaction(txID: "battery-\($0)", timestamp: Int64(1000 - $0)) }
        let rhs = (0 ..< 20).map { transaction(txID: "grid-\($0)", timestamp: Int64(500 - $0)) }

        let first = TronUSDTAPI.mergeDeduplicatingByTxID(lhs, rhs).map(\.txID)
        for _ in 0 ..< 5 {
            XCTAssertEqual(TronUSDTAPI.mergeDeduplicatingByTxID(lhs, rhs).map(\.txID), first)
        }
    }

    private func transaction(txID: String, timestamp: Int64, amount: String = "10") -> TronTransaction {
        try! JSONDecoder().decode(TronTransaction.self, from: Data(
            """
            {
              "txid": "\(txID)",
              "timestamp": \(timestamp),
              "from_account": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
              "to_account": "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb",
              "amount": "\(amount)",
              "is_pending": false,
              "is_failed": false
            }
            """.utf8
        ))
    }
}
