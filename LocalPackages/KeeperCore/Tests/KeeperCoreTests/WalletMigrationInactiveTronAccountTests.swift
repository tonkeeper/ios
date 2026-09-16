@testable import KeeperCore
import XCTest

final class WalletMigrationInactiveTronAccountTests: XCTestCase {
    func test_inactiveTronAccount_errorIsDistinct() {
        let error = WalletMigrationError.inactiveTronAccount
        XCTAssertEqual(error, .inactiveTronAccount)
        XCTAssertNotEqual(error, .insufficientTrxForFees(required: 1, available: 0))
    }

    func test_executionInactiveTronAccount_isDistinct() {
        let error = WalletMigrationExecutionError.inactiveTronAccount
        switch error {
        case .inactiveTronAccount:
            break
        default:
            XCTFail("Expected inactiveTronAccount")
        }
    }
}
