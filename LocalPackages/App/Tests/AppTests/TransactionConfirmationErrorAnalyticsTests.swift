@testable import App
import KeeperCore
import XCTest

final class TransactionConfirmationErrorAnalyticsTests: XCTestCase {
    func testUnavailableFeeIsClassifiedUnderTheFeeCategoryRatherThanSendFailure() {
        let error = TransactionConfirmationError.multichainTransactionFailure(.feeMethodUnavailable)

        XCTAssertEqual(error.type, .feeCalculationFailed)
        XCTAssertEqual(error.code, 1)
        XCTAssertEqual(error.transactionConfirmationStage, "fee")
        XCTAssertEqual(error.message, "type=MultichainTransactionFailure, case=feeMethodUnavailable")
    }

    func testRelayerIntegrityRefusalsKeepTheSendCategory() {
        let error = TransactionConfirmationError.multichainTransactionFailure(.relayerQuoteUnavailable(reason: "operation differs from confirmed transfer"))

        XCTAssertEqual(error.type, .transactionSendFailed)
        XCTAssertEqual(error.code, 2)
        XCTAssertEqual(error.transactionConfirmationStage, "send")
    }

    func testKnownFeeWithInsufficientFundsKeepsTheSendCategory() {
        let error = TransactionConfirmationError.multichainTransactionFailure(.insufficientSelectedFee)

        XCTAssertEqual(error.type, .transactionSendFailed)
        XCTAssertEqual(error.code, 2)
        XCTAssertEqual(error.transactionConfirmationStage, "send")
    }

    func testLoadingFeeIsClassifiedUnderTheFeeCategoryRatherThanSendFailure() {
        let error = TransactionConfirmationError.multichainTransactionFailure(.feeQuoteLoading)

        XCTAssertEqual(error.type, .feeCalculationFailed)
        XCTAssertEqual(error.code, 1)
        XCTAssertEqual(error.transactionConfirmationStage, "fee")
        XCTAssertEqual(error.message, "type=MultichainTransactionFailure, case=feeQuoteLoading")
    }

    func test_anOperationThatExpiredBeforeSigningIsNotReportedAsARelayerQuoteFailure() {
        let error = TransactionConfirmationError.multichainTransactionFailure(.operationExpired)

        XCTAssertEqual(error.message, "type=MultichainTransactionFailure, case=operationExpired")
        XCTAssertEqual(error.type, .transactionSendFailed)
    }

    func test_failureWithoutDetails_fallsBackToItsCategory() {
        XCTAssertEqual(TransactionConfirmationError.failedToCalculateFee(message: nil).message, "Failed to calculate fee")
        XCTAssertEqual(TransactionConfirmationError.failedToSendTransaction(message: nil).message, "Failed to send transaction")
        XCTAssertEqual(TransactionConfirmationError.failedToSign(message: nil).message, "Failed to sign transaction")
    }

    func test_feeFailureReportsItsReasonUnderTheFeeCode() {
        let error = TransactionConfirmationError.failedToCalculateFee(message: "500 cannot apply external message")

        XCTAssertEqual(error.message, "500 cannot apply external message")
        XCTAssertEqual(error.code, 1)
        XCTAssertEqual(error.type, .feeCalculationFailed)
    }

    func test_multichainFailureReportsItsCaseAndKind() {
        let error = TransactionConfirmationError.multichainTransactionFailure(
            .failedToSendSigned(kind: .networkError, reason: "timed out")
        )

        XCTAssertEqual(
            error.message,
            "type=MultichainTransactionFailure, case=failedToSendSigned, kind=\(MultichainSwapExecutionErrorKind.networkError.description)"
        )
    }

    func test_sendAndSignFailuresStayTransactionSendFailures() {
        XCTAssertEqual(TransactionConfirmationError.failedToSendTransaction(message: nil).type, .transactionSendFailed)
        XCTAssertEqual(TransactionConfirmationError.failedToSign(message: nil).type, .transactionSendFailed)
        XCTAssertEqual(TransactionConfirmationError.failedToSendTransaction(message: nil).transactionConfirmationStage, "send")
        XCTAssertEqual(TransactionConfirmationError.failedToSign(message: nil).transactionConfirmationStage, "send")
    }
}
