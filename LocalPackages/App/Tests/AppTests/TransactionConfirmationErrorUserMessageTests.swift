@testable import App
@testable import KeeperCore
import TKLocalize
import XCTest

final class TransactionConfirmationErrorUserMessageTests: XCTestCase {
    func test_anOperationThatExpiredBeforeSigningShowsExpiryRatherThanAFeeFailure() {
        XCTAssertEqual(
            TransactionConfirmationError.multichainTransactionFailure(.operationExpired).userMessage,
            TKLocales.SignMessage.Error.expired
        )
    }

    func test_failureReadsItsLocalizedTextNotTheReason() {
        let error = TransactionConfirmationError.failedToSendTransaction(
            message: "failed to single default send due to error: 500 cannot apply external message"
        )

        XCTAssertEqual(error.userMessage, TKLocales.Multichain.Transaction.Error.failedToSend)
    }

    func test_failureWithATextOfItsOwnReadsIt() {
        let error = TransactionConfirmationError.failedToSendTransaction(
            message: "rejected BANDWITH_ERROR: account resource insufficient",
            localizedMessage: TKLocales.TronUsdtFees.InsufficientPopup.title
        )

        XCTAssertEqual(error.userMessage, TKLocales.TronUsdtFees.InsufficientPopup.title)
    }

    func test_batteryRefusalForLackOfFunds_readsTheFeeShortageText() {
        let error = TransactionConfirmationError(
            transferFailure: .sendFailed(
                message: "failed to single gasless send due to error: 402",
                refusal: RelayerRefusal(status: 402, code: "err-gasless-balance")
            )
        )

        XCTAssertEqual(error.userMessage, TKLocales.TronUsdtFees.InsufficientPopup.title)
    }

    func test_eachFailureHasItsOwnText() {
        XCTAssertEqual(
            TransactionConfirmationError.failedToCalculateFee(message: "502").userMessage,
            TKLocales.Multichain.Transaction.Error.failedToCalculateFee
        )
        XCTAssertEqual(
            TransactionConfirmationError.failedToSign(message: "Unsupported wallet kind").userMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.signInternalError
        )
    }

    func test_cancelShowsNothing() {
        XCTAssertNil(TransactionConfirmationError.cancelledByUser.userMessage)
    }
}
