@testable import KeeperCore
import XCTest

final class TronTransactionCodingTests: XCTestCase {
    func test_cachedTransactionWithoutTokenIsUSDT() throws {
        let transaction = try JSONDecoder().decode(TronTransaction.self, from: json(tokenField: ""))

        XCTAssertEqual(transaction.token, .usdt)
    }

    func test_tokenSurvivesRoundTrip() throws {
        let decoded = try JSONDecoder().decode(TronTransaction.self, from: json(tokenField: #","token":"trx""#))

        let reencoded = try JSONDecoder().decode(TronTransaction.self, from: JSONEncoder().encode(decoded))

        XCTAssertEqual(reencoded.token, .trx)
    }

    private func json(tokenField: String) -> Data {
        Data(
            """
            {
              "txid": "tx",
              "timestamp": 1,
              "from_account": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
              "to_account": "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb",
              "amount": "10",
              "is_pending": false,
              "is_failed": false\(tokenField)
            }
            """.utf8
        )
    }
}
