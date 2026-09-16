@testable import KeeperCore
import TronSwiftAPI
import XCTest

final class WalletMigrationTronLegFailureTests: XCTestCase {
    /// The node refuses to build the transaction with a bare `Error` string when the balance moved
    /// between prepare and send; that has to reach the user as a top-up prompt, not as the node's
    /// own exception text.
    func test_buildTimeShortage_mapsToInsufficientTronFee() {
        let error = TronApi.Error.apiError(
            message: "class org.tron.core.exception.ContractValidateException : Validate TransferContract error, balance is not sufficient."
        )

        assertMaps(error, to: .insufficientTronFee)
    }

    func test_broadcastShortage_mapsToInsufficientTronFee() {
        let error = TronApi.Error.transactionRejected(
            code: "BANDWITH_ERROR",
            message: "account resource insufficient"
        )

        assertMaps(error, to: .insufficientTronFee)
    }

    func test_missingAccount_mapsToInactiveTronAccount() {
        let error = TronApi.Error.apiError(
            message: "class org.tron.core.exception.ContractValidateException : Account does not exist!"
        )

        assertMaps(error, to: .inactiveTronAccount)
    }

    func test_signFailure_mapsToSigningFailed() {
        assertMaps(TronTransferSignError.cancelled, to: .signingFailed)
    }

    func test_migrationErrorPassesThroughUnchanged() {
        assertMaps(WalletMigrationExecutionError.unsupportedWalletKind, to: .unsupportedWalletKind)
    }

    func test_unclassifiedFailure_keepsTheMessage() {
        let error = TronApi.Error.apiError(message: "Failed to create TRX transfer")

        guard case let .sendFailed(message) = WalletMigrationTronLegFailure.map(error) else {
            return XCTFail("Expected sendFailed")
        }
        XCTAssertEqual(message, "Failed to create TRX transfer")
    }

    private func assertMaps(
        _ error: Swift.Error,
        to expected: WalletMigrationExecutionError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            String(describing: WalletMigrationTronLegFailure.map(error)),
            String(describing: expected),
            file: file,
            line: line
        )
    }
}
