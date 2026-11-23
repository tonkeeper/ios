import Foundation
@testable import KeeperCore
import TKTestSupport
import XCTest

final class TimeLimitTests: XCTestCase {
    func test_withTimeLimit_returnsValue_whenOperationFinishesWithinLimit() async {
        let value = await withTimeLimit(10) {
            "finished"
        }

        XCTAssertEqual(value, "finished")
    }

    func test_withTimeLimit_returnsNil_whenLimitElapsesFirst() async {
        let release = TestGate()
        let value = await limitResult(holding: release) {
            await withTimeLimit(0.05) {
                try? await release.wait()
                return "finished"
            }
        }

        XCTAssertNil(value)
    }

    func test_withTimeLimit_leavesOperationRunningUncancelled_whenLimitElapsesFirst() async {
        let outcome = OperationOutcome()

        let release = TestGate()
        let value = await limitResult(holding: release) {
            await withTimeLimit(0.05) {
                try? await release.wait()
                await outcome.finish(wasCancelled: Task.isCancelled)
            }
        }

        XCTAssertNil(value)
        let wasCancelled = await outcome.wasCancelled()
        XCTAssertEqual(wasCancelled, false)
    }
}

private extension TimeLimitTests {
    func limitResult<Value: Sendable>(
        holding release: TestGate,
        _ limited: @escaping @Sendable () async -> Value?
    ) async -> Value? {
        let returned = expectation(description: "the limit returns while the operation is held")
        let result = Task {
            let value = await limited()
            returned.fulfill()
            return value
        }
        await fulfillment(of: [returned], timeout: 1)
        await release.open()
        return await result.value
    }
}

private actor OperationOutcome {
    private var finished: Bool?
    private var continuation: CheckedContinuation<Bool, Never>?

    func finish(wasCancelled: Bool) {
        finished = wasCancelled
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: wasCancelled)
    }

    func wasCancelled() async -> Bool {
        if let finished {
            return finished
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}
