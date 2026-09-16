@testable import App
import XCTest

final class PasscodeInputViewModelTests: XCTestCase {
    /// Regression: when the screen is presented already locked, a racing biometry auto-fill (or any input)
    /// arriving before `viewWillAppear` arms the lockout must NOT be validated. See TK-1472.
    func test_lockedAtPresentation_ignoresInput() {
        let viewModel = PasscodeInputViewModelImplementation(
            title: "Enter",
            initialLockoutUntil: Date().addingTimeInterval(60)
        )
        var validateCalled = false
        viewModel.validateInput = { _ in
            validateCalled = true
            return .success
        }

        viewModel.didSetInput("1234")

        XCTAssertFalse(validateCalled, "Input must be ignored while presented locked")
    }

    func test_notLocked_acceptsInput() {
        let viewModel = PasscodeInputViewModelImplementation(title: "Enter", initialLockoutUntil: nil)
        let validated = expectation(description: "validateInput called")
        viewModel.validateInput = { _ in
            validated.fulfill()
            return .success
        }

        viewModel.didSetInput("1234")

        wait(for: [validated], timeout: 1.0)
    }

    /// After a lockout ends, the host must be told so it can re-request biometry first. See TK-1472.
    func test_lockoutExpiredOnAppear_firesDidEndLockout() {
        let viewModel = PasscodeInputViewModelImplementation(
            title: "Enter",
            initialLockoutUntil: Date().addingTimeInterval(-1)
        )
        var ended = false
        viewModel.didEndLockout = { ended = true }

        viewModel.viewWillAppear()

        XCTAssertTrue(ended, "An already-expired lockout must notify the host on appear")
    }

    func test_notLocked_doesNotFireDidEndLockout() {
        let viewModel = PasscodeInputViewModelImplementation(title: "Enter", initialLockoutUntil: nil)
        var ended = false
        viewModel.didEndLockout = { ended = true }

        viewModel.viewWillAppear()

        XCTAssertFalse(ended, "No lockout was active, so biometry must not be re-prompted")
    }
}
