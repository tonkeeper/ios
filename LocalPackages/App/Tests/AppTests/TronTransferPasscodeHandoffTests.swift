@testable import App
import XCTest

@MainActor
final class TronTransferPasscodeHandoffTests: XCTestCase {
    func testBatteryUnlockRemainsAvailableAcrossTronAndTonSigning() {
        let handoff = TronTransferPasscodeHandoff()
        handoff.storeForCurrentOperation("1234")

        XCTAssertEqual(handoff.currentOperationPasscode, "1234")
        XCTAssertEqual(handoff.currentOperationPasscode, "1234")
        XCTAssertEqual(handoff.take(), "1234")
        XCTAssertNil(handoff.currentOperationPasscode)
        XCTAssertNil(handoff.take())
    }

    func testPreviousTimedUnlockCannotStartAnotherTronSend() {
        let handoff = TronTransferPasscodeHandoff()
        handoff.store("1234")

        XCTAssertNil(handoff.currentOperationPasscode)
        XCTAssertEqual(handoff.take(), "1234")
    }

    func testFailedAttemptClearsItsUnlock() {
        let handoff = TronTransferPasscodeHandoff()
        handoff.storeForCurrentOperation("1234")

        handoff.discard()

        XCTAssertNil(handoff.currentOperationPasscode)
        XCTAssertNil(handoff.take())
    }

    func testAnotherConfirmationDoesNotShareBatteryUnlock() {
        let current = TronTransferPasscodeHandoff()
        let another = TronTransferPasscodeHandoff()
        current.storeForCurrentOperation("1234")

        XCTAssertNil(another.currentOperationPasscode)
        XCTAssertNil(another.take())
        XCTAssertEqual(current.currentOperationPasscode, "1234")
    }
}
