@testable import App
import XCTest

final class RemoteConfigFetchDeadlineTests: XCTestCase {
    func testDeadlineEndsTheWaitWhileFetchIgnoresCancellation() async {
        let fetch = PendingFetch()

        let outcome = await TKFirebaseRemoteConfigProvider.withDeadline(ms: 10) {
            await fetch.wait()
        }

        guard case .deadlineExceeded = outcome else {
            return XCTFail("Expected the deadline, got \(outcome)")
        }
        fetch.finish()
    }

    func testFetchThatEndsBeforeDeadlineIsReported() async {
        let outcome = await TKFirebaseRemoteConfigProvider.withDeadline(ms: 60000) {}

        guard case .finished = outcome else {
            return XCTFail("Expected a fetch, got \(outcome)")
        }
    }

    func testFetchErrorIsReported() async {
        let outcome = await TKFirebaseRemoteConfigProvider.withDeadline(ms: 60000) {
            throw URLError(.notConnectedToInternet)
        }

        guard case let .failed(error) = outcome else {
            return XCTFail("Expected a failure, got \(outcome)")
        }
        XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }
}

/// A fetch that does not react to cancellation and ends only when the test ends it.
private final class PendingFetch: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var isFinished = false

    func wait() async {
        await withCheckedContinuation { continuation in
            let isFinished = lock.withLock {
                if !self.isFinished {
                    self.continuation = continuation
                }
                return self.isFinished
            }
            if isFinished {
                continuation.resume()
            }
        }
    }

    func finish() {
        let continuation = lock.withLock {
            isFinished = true
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume()
    }
}
