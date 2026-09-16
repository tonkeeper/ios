@testable import App
import KeeperCore
import TKCore
import XCTest

final class WalletMigrationSendFailureMessageTests: XCTestCase {
    func test_sendFailed_extractsMessage() {
        let message = WalletMigrationSendFailureMessage.extract(
            from: WalletMigrationExecutionError.sendFailed(message: "user is disabled, try later")
        )
        XCTAssertEqual(message, "user is disabled, try later")
    }

    func test_partiallySentInsidePartFailure_extractsUnderlyingMessage() {
        let failure = WalletMigrationPartFailure(
            part: .ton,
            isPartial: true,
            underlying: WalletMigrationExecutionError.partiallySent(message: "relay rejected boc")
        )
        XCTAssertEqual(WalletMigrationSendFailureMessage.extract(from: failure), "relay rejected boc")
    }

    func test_whitespaceOnlyMessage_returnsNil() {
        let message = WalletMigrationSendFailureMessage.extract(
            from: WalletMigrationExecutionError.sendFailed(message: " \n")
        )
        XCTAssertNil(message)
    }

    func test_semanticExecutionErrors_returnNil() {
        XCTAssertNil(
            WalletMigrationSendFailureMessage.extract(
                from: WalletMigrationExecutionError.signingFailed
            )
        )
        XCTAssertNil(
            WalletMigrationSendFailureMessage.extract(
                from: WalletMigrationExecutionError.insufficientTronFee
            )
        )
    }

    func test_nonExecutionError_returnsNil() {
        XCTAssertNil(
            WalletMigrationSendFailureMessage.extract(from: CancellationError())
        )
    }
}
