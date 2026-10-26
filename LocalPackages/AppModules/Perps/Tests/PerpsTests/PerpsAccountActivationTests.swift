@testable import Perps
import XCTest

@MainActor
final class PerpsAccountActivationTests: XCTestCase {
    private var activations = 0

    private func activate(succeeding: Bool) -> @MainActor () async -> Bool {
        { [weak self] in
            self?.activations += 1
            return succeeding
        }
    }

    func test_success_answersUntilTheStoreConfirms() async {
        let activation = PerpsAccountActivation()

        let first = await activation.ensureReady(needsActivation: true, activate: activate(succeeding: true))
        // The refresh the activation started has not landed: the store still reports the key missing.
        let beforeConfirmation = await activation.ensureReady(needsActivation: true, activate: activate(succeeding: true))

        XCTAssertTrue(first)
        XCTAssertTrue(beforeConfirmation)
        XCTAssertEqual(activations, 1)
    }

    func test_keyMissingAfterConfirmation_activatesAgain() async {
        let activation = PerpsAccountActivation()
        _ = await activation.ensureReady(needsActivation: true, activate: activate(succeeding: true))

        activation.accountConfirmed()
        let again = await activation.ensureReady(needsActivation: true, activate: activate(succeeding: true))

        XCTAssertTrue(again)
        XCTAssertEqual(activations, 2)
    }

    func test_storeConfirmationDoesNotClearAnActivationStillWaitingForPasscode() async {
        let activation = PerpsAccountActivation()
        let started = expectation(description: "activation is waiting")
        var finish: CheckedContinuation<Bool, Never>?
        let first = Task {
            await activation.ensureReady(needsActivation: true) {
                self.activations += 1
                return await withCheckedContinuation { continuation in
                    finish = continuation
                    started.fulfill()
                }
            }
        }
        await fulfillment(of: [started], timeout: 2)
        activation.accountConfirmed()

        let entered = expectation(description: "both callers entered")
        entered.expectedFulfillmentCount = 2
        let ready = Task {
            entered.fulfill()
            return await activation.ensureReady(needsActivation: false, activate: activate(succeeding: true))
        }
        let duplicate = Task {
            entered.fulfill()
            return await activation.ensureReady(needsActivation: true, activate: activate(succeeding: true))
        }
        await fulfillment(of: [entered], timeout: 2)
        finish?.resume(returning: false)

        let firstResult = await first.value
        let readyResult = await ready.value
        let duplicateResult = await duplicate.value
        XCTAssertFalse(firstResult)
        XCTAssertFalse(readyResult)
        XCTAssertFalse(duplicateResult)
        XCTAssertEqual(activations, 1)
    }

    func test_failure_isNotRemembered() async {
        let activation = PerpsAccountActivation()

        let failed = await activation.ensureReady(needsActivation: true, activate: activate(succeeding: false))
        let retried = await activation.ensureReady(needsActivation: true, activate: activate(succeeding: true))

        XCTAssertFalse(failed)
        XCTAssertTrue(retried)
        XCTAssertEqual(activations, 2)
    }

    func test_activatedAccount_isReadyWithoutActivating() async {
        let activation = PerpsAccountActivation()

        let ready = await activation.ensureReady(needsActivation: false, activate: activate(succeeding: false))

        XCTAssertTrue(ready)
        XCTAssertEqual(activations, 0)
    }
}
