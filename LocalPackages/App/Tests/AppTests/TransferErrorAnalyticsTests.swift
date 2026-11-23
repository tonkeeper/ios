@testable import App
import KeeperCore
import XCTest

final class TransferErrorAnalyticsTests: XCTestCase {
    func test_transferThatCouldNotBeBuilt_readsAsTheTransfersReportIt() {
        let error = TransferError.noJettonWalletAddress

        XCTAssertEqual(error.message, TransactionConfirmationError(transferFailure: error).message)
        XCTAssertEqual(error.message, "failed to prepare transaction: \(error.logDescription)")
    }

    func test_refusedBroadcast_readsItsReason() {
        let error = TransferError.sendFailed(message: "failed to single battery send due to error: 400")

        XCTAssertEqual(error.message, "failed to single battery send due to error: 400")
    }
}
