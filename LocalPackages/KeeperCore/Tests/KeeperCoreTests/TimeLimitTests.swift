import Foundation
@testable import KeeperCore
import XCTest

final class TimeLimitTests: XCTestCase {
    func test_withTimeLimit_returnsValue_whenOperationFinishesWithinLimit() async {
        let value = await withTimeLimit(10) {
            "finished"
        }

        XCTAssertEqual(value, "finished")
    }

    func test_withTimeLimit_returnsNil_whenLimitElapsesFirst() async {
        let value = await withTimeLimit(0.05) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return "finished"
        }

        XCTAssertNil(value)
    }

    func test_withTimeLimit_leavesOperationRunningUncancelled_whenLimitElapsesFirst() async {
        let outcome = OperationOutcome()

        let value = await withTimeLimit(0.05) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await outcome.finish(wasCancelled: Task.isCancelled)
        }

        XCTAssertNil(value)
        let wasCancelled = await outcome.wasCancelled()
        XCTAssertEqual(wasCancelled, false)
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
