@testable import App
import KeeperCore
import TKCore
import XCTest

final class WalletMigrationPartFailureTests: XCTestCase {
    func test_partiallySentBatch_marksPartAsPartial() async {
        do {
            try await withMigrationPart(.ton, isPartial: false) {
                throw WalletMigrationExecutionError.partiallySent(message: "failed")
            }
            XCTFail("Expected failure")
        } catch let failure as WalletMigrationPartFailure {
            XCTAssertEqual(failure.part, .ton)
            XCTAssertTrue(failure.isPartial)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_firstSendFailure_keepsPartNonPartial() async {
        do {
            try await withMigrationPart(.ton, isPartial: false) {
                throw WalletMigrationExecutionError.sendFailed(message: "failed")
            }
            XCTFail("Expected failure")
        } catch let failure as WalletMigrationPartFailure {
            XCTAssertEqual(failure.part, .ton)
            XCTAssertFalse(failure.isPartial)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
