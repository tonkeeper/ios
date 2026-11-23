@testable import KeeperCore
import TronSwiftAPI
import XCTest

final class TronExpirationRetryTests: XCTestCase {
    private static let expired = TronApi.Error.transactionRejected(
        code: "TRANSACTION_EXPIRATION_ERROR",
        message: "Transaction expired"
    )

    func test_expiredDirectSend_isRebuiltAndResent() async throws {
        var attempts = 0

        let txID = try await TronExpirationRetry.run(isEnabled: true) {
            attempts += 1
            if attempts == 1 {
                throw Self.expired
            }
            return "tx-\(attempts)"
        }

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(txID, "tx-2", "the txID that goes up must be the one actually broadcast")
    }

    /// One found expired before it was signed is what the chain would refuse: it is built again too.
    func test_transactionFoundExpiredBeforeItsSignature_isRebuilt() async throws {
        var attempts = 0

        let txID = try await TronExpirationRetry.run(isEnabled: true) {
            attempts += 1
            if attempts == 1 {
                throw TronExpirationRetry.Expired()
            }
            return "tx-\(attempts)"
        }

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(txID, "tx-2")
    }

    func test_expiredRelaySend_isReportedAsIs() async {
        var attempts = 0

        await XCTAssertThrowsErrorAsync(
            try await TronExpirationRetry.run(isEnabled: false) {
                attempts += 1
                throw Self.expired
            }
        )

        XCTAssertEqual(attempts, 1)
    }

    func test_secondExpiration_isNotRetriedAgain() async {
        var attempts = 0

        await XCTAssertThrowsErrorAsync(
            try await TronExpirationRetry.run(isEnabled: true) {
                attempts += 1
                throw Self.expired
            }
        )

        XCTAssertEqual(attempts, 2)
    }

    func test_otherFailure_isNotRetried() async {
        var attempts = 0

        await XCTAssertThrowsErrorAsync(
            try await TronExpirationRetry.run(isEnabled: true) {
                attempts += 1
                throw TronApi.Error.transactionRejected(code: "BANDWITH_ERROR", message: nil)
            }
        )

        XCTAssertEqual(attempts, 1)
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Any,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {}
}
