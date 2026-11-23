#if DEBUG
    @testable import LedgerKit
    import Network
    import XCTest

    final class LabLedgerTransportTests: XCTestCase {
        func testQueuedFailureAndCancellationKeepTheFirstConnectionError() async {
            let events = LabLedgerConnectionEvents()
            XCTAssertTrue(events.update(.waiting(.posix(.ECONNRESET))))
            events.update(.failed(.posix(.ECONNRESET)))
            events.update(.cancelled)

            do {
                try await events.waitUntilConnected()
                XCTFail("A failed connection must not become ready")
            } catch LedgerTransportError.peripheralNotFound {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            await assertDisconnected(events)
        }

        func testLateReadyDoesNotReplaceFailure() async {
            let events = LabLedgerConnectionEvents()
            XCTAssertTrue(events.update(.failed(.posix(.ECONNREFUSED))))
            events.update(.ready)

            do {
                try await events.waitUntilConnected()
                XCTFail("A late ready callback must not replace the failure")
            } catch LedgerTransportError.peripheralNotFound {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testLateFailureDoesNotReplaceCancellation() async {
            let events = LabLedgerConnectionEvents()
            events.update(.cancelled)
            events.update(.failed(.posix(.ECONNRESET)))
            events.update(.ready)

            do {
                try await events.waitUntilConnected()
                XCTFail("A cancelled connection must not become ready")
            } catch is CancellationError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            await assertDisconnected(events)
        }

        func testRepeatedReadyAndTerminalCallbacksCompleteConnectionOnce() async throws {
            let events = LabLedgerConnectionEvents()
            XCTAssertFalse(events.update(.setup))
            XCTAssertFalse(events.update(.preparing))
            events.update(.ready)
            events.update(.ready)
            events.update(.failed(.posix(.ECONNRESET)))
            events.update(.cancelled)

            var completions = 0
            for await result in events.readiness {
                try result.get()
                completions += 1
            }
            XCTAssertEqual(completions, 1)
            await assertDisconnected(events)
        }

        func testWaitingBeforeReadyFailsAndCancels() async {
            let events = LabLedgerConnectionEvents()
            XCTAssertTrue(events.update(.waiting(.posix(.ENETDOWN))))

            do {
                try await events.waitUntilConnected()
                XCTFail("A waiting connection must not become ready")
            } catch LedgerTransportError.peripheralNotFound {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            await assertDisconnected(events)
        }

        func testWaitingAfterReadyKeepsTheConnectionOpen() async throws {
            let events = LabLedgerConnectionEvents()
            XCTAssertFalse(events.update(.ready))
            XCTAssertFalse(events.update(.waiting(.posix(.ENETDOWN))))
            XCTAssertFalse(events.update(.ready))
            try await events.waitUntilConnected()

            XCTAssertTrue(events.update(.failed(.posix(.ECONNRESET))))
            await assertDisconnected(events)
        }

        func testCancellingTheWaitDoesNotReturnAnUnconnectedLink() async {
            let events = LabLedgerConnectionEvents()
            let waiting = expectation(description: "Waiting for connection")
            let task = Task {
                waiting.fulfill()
                try await events.waitUntilConnected()
            }
            await fulfillment(of: [waiting], timeout: 1)
            task.cancel()

            do {
                try await task.value
                XCTFail("Cancellation must reach the caller")
            } catch is CancellationError {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            events.update(.ready)
            events.update(.cancelled)
            await assertDisconnected(events)
        }

        private func assertDisconnected(_ events: LabLedgerConnectionEvents) async {
            var emissions = 0
            for await _ in events.disconnected {
                emissions += 1
            }
            XCTAssertEqual(emissions, 0, "The disconnect stream must finish without extra signals")
        }
    }
#endif
