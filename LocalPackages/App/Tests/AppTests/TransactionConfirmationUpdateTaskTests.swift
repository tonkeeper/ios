@testable import App
import TKTestSupport
import XCTest

@MainActor
final class TransactionConfirmationUpdateTaskTests: XCTestCase {
    func testOldCompletionPreservesCancellationOfTheReplacementOnClose() async throws {
        try await assertReplacementIsCancelled(startThirdUpdate: false)
    }

    func testThirdUpdateCancelsTheReplacementAfterTheOldUpdateFinished() async throws {
        try await assertReplacementIsCancelled(startThirdUpdate: true)
    }

    private func assertReplacementIsCancelled(startThirdUpdate: Bool) async throws {
        let updates = TransactionConfirmationUpdateTask()
        let oldStarted = TestGate()
        let oldRelease = TestGate()
        let oldFinished = expectation(description: "old update finished")
        let replacementStarted = TestGate()
        let replacementRelease = TestGate()
        let replacementFinished = expectation(description: "replacement finished")
        var replacementCancelled = false
        var staleCallbacks = 0
        updates.replace {
            await oldStarted.open()
            await Task { try? await oldRelease.wait() }.value
            oldFinished.fulfill()
        }
        try await oldStarted.wait()
        updates.replace {
            await replacementStarted.open()
            try? await replacementRelease.wait()
            replacementCancelled = Task.isCancelled
            if !Task.isCancelled { staleCallbacks += 1 }
            replacementFinished.fulfill()
        }
        try await replacementStarted.wait()
        await oldRelease.open()
        await fulfillment(of: [oldFinished], timeout: 5)
        if startThirdUpdate {
            updates.replace {}
        } else {
            updates.cancel()
        }
        await fulfillment(of: [replacementFinished], timeout: 5)
        await replacementRelease.open()
        updates.cancel()
        XCTAssertTrue(replacementCancelled)
        XCTAssertEqual(staleCallbacks, 0)
    }
}
