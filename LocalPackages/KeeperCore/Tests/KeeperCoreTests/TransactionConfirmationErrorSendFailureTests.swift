@testable import KeeperCore
import XCTest

final class TransactionConfirmationErrorSendFailureTests: XCTestCase {
    func test_transferFailure_nothingToSendReadsAsPreparationFailure() {
        let error = TransactionConfirmationError(transferFailure: .nothingToSend)

        guard case let .failedToSendTransaction(message, _) = error else {
            return XCTFail("expected failedToSendTransaction, got \(error)")
        }
        XCTAssertEqual(message, "failed to prepare transaction: \(TransferError.nothingToSend.logDescription)")
    }

    func test_refusedBroadcast_keepsTheRefusalMessage() {
        let error = TransactionConfirmationError(
            sendFailure: .firstOption(.sendFailed(message: "not enough charges"))
        )

        guard case let .failedToSendTransaction(message, localizedMessage) = error else {
            return XCTFail("expected failedToSendTransaction, got \(error)")
        }
        XCTAssertEqual(message, "not enough charges")
        XCTAssertNil(localizedMessage)
    }

    func test_relayerRefusalForLackOfFunds_tellsTheUserSo() {
        let reason = "failed to single gasless send due to error: 402 not enough balance"
        let error = TransactionConfirmationError(
            transferFailure: .sendFailed(message: reason, refusal: RelayerRefusal(status: 402, code: "err-gasless-balance"))
        )

        guard case let .failedToSendTransaction(message, localizedMessage) = error else {
            return XCTFail("expected failedToSendTransaction, got \(error)")
        }
        XCTAssertEqual(message, reason)
        XCTAssertNotNil(localizedMessage)
    }

    func test_relayerRefusalForAnotherReason_keepsTheGenericText() {
        let error = TransactionConfirmationError(
            transferFailure: .sendFailed(message: "refused", refusal: RelayerRefusal(status: 400, code: "err-gasless-pending-messages"))
        )

        guard case let .failedToSendTransaction(_, localizedMessage) = error else {
            return XCTFail("expected failedToSendTransaction, got \(error)")
        }
        XCTAssertNil(localizedMessage)
    }

    func test_transferThatCouldNotBeBuilt_readsAsPreparationFailure() throws {
        let error = TransactionConfirmationError(
            sendFailure: .firstOption(.failedToCreateTransferData(message: "failed to get seqno due to error: 503"))
        )

        guard case let .failedToSendTransaction(message, _) = error else {
            return XCTFail("expected failedToSendTransaction, got \(error)")
        }
        let text = try XCTUnwrap(message)
        XCTAssertTrue(text.hasPrefix("failed to prepare transaction: "), text)
        XCTAssertTrue(text.contains("case=failedToCreateTransferData"), text)
        XCTAssertTrue(text.contains("message=failed to get seqno due to error: 503"), text)
    }

    func test_signingFailure_keepsItsOwnCase() {
        let error = TransactionConfirmationError(
            sendFailure: .secondOption(.failedToSign(message: "ledger disconnected"))
        )

        guard case let .failedToSign(message) = error else {
            return XCTFail("expected failedToSign, got \(error)")
        }
        XCTAssertEqual(message, "ledger disconnected")
    }

    func test_cancellation_staysCancellation() {
        let error = TransactionConfirmationError(sendFailure: .secondOption(.cancelledByUser))

        XCTAssertTrue(error.isCancel)
    }
}
