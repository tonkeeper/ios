@testable import App
import MoonPay
import XCTest

@MainActor
final class MoonPayTransactionPollerTests: XCTestCase {
    private let transaction = MoonPayTransaction(id: "tx_1", status: "pending")
    private var clock = Date(timeIntervalSince1970: 0)
    private var fetches = 0

    func test_completedInTheSlowPhase_reportsStillProcessingThenCompleted() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        let poller = makePoller { fetch, _ in
            fetch == quickCount + 3 ? Self.details("completed") : Self.details("pending")
        }

        let updates = await run(poller)

        XCTAssertEqual(updates, [
            .stillProcessing(transaction),
            .completed(MoonPayTransaction(id: "tx_1", status: "completed")),
        ])
        XCTAssertEqual(fetches, quickCount + 3)
        XCTAssertEqual(clock.timeIntervalSince1970, 60 + 3 * 15)
    }

    func test_slowPolls_endAtTheDeadlineWithAnUnknownOutcome() async {
        let poller = makePoller { _, _ in Self.details("pending") }

        let updates = await run(poller)

        XCTAssertEqual(updates, [.stillProcessing(transaction), .outcomeUnknown])
        XCTAssertEqual(fetches, MoonPayTransactionPoller.quickPollIntervals.count + 120)
        XCTAssertEqual(clock.timeIntervalSince1970, 60 + MoonPayTransactionPoller.slowPollDuration)
    }

    func test_aPaymentSettledWhileTheDeviceSlept_showsCompleted() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        var sleeps = 0
        let poller = MoonPayTransactionPoller(
            fetch: { [unowned self] _, _ in
                fetches += 1
                return Self.details(fetches > quickCount ? "completed" : "pending")
            },
            sleep: { [unowned self] nanoseconds in
                sleeps += 1
                // The device sleeps through the first slow interval, past the whole window.
                let asleep = sleeps == quickCount + 1 ? MoonPayTransactionPoller.slowPollDuration : 0
                clock = clock.addingTimeInterval(TimeInterval(nanoseconds) / 1_000_000_000 + asleep)
            },
            now: { [unowned self] in clock }
        )

        let updates = await run(poller)

        XCTAssertEqual(updates, [
            .stillProcessing(transaction),
            .completed(MoonPayTransaction(id: "tx_1", status: "completed")),
        ])
        XCTAssertEqual(fetches, quickCount + 1)
    }

    func test_aTransientError_isRetried() async {
        for status in [408, 425, 503] {
            fetches = 0
            let poller = makePoller { fetch, _ in
                if fetch == 1 { throw MoonPayAPIError.http(status: status, body: nil) }
                return Self.details("completed")
            }

            let updates = await run(poller)

            XCTAssertEqual(updates, [.completed(MoonPayTransaction(id: "tx_1", status: "completed"))], "\(status)")
            XCTAssertEqual(fetches, 2, "\(status)")
        }
    }

    func test_aFinalError_stopsPolling() async {
        for status in [400, 401, 403, 404] {
            fetches = 0
            let poller = makePoller { _, _ in throw MoonPayAPIError.http(status: status, body: nil) }

            let updates = await run(poller)

            XCTAssertEqual(updates, [.outcomeUnknown], "\(status)")
            XCTAssertEqual(fetches, 1, "\(status)")
        }
    }

    func test_slowPolls_reconnectOnlySilently() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        var allowedSignIn: [Bool] = []
        let poller = makePoller { fetch, allowsSignIn in
            allowedSignIn.append(allowsSignIn)
            return fetch == quickCount + 2 ? Self.details("completed") : Self.details("pending")
        }

        _ = await run(poller)

        XCTAssertEqual(allowedSignIn, Array(repeating: true, count: quickCount) + [false, false])
    }

    func test_aRequiredSignIn_stopsTheSlowPhase() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        let poller = makePoller { _, allowsSignIn in
            if !allowsSignIn { throw MoonPayRampError.signInRequired }
            return Self.details("pending")
        }

        let updates = await run(poller)

        XCTAssertEqual(updates, [.stillProcessing(transaction), .outcomeUnknown])
        XCTAssertEqual(fetches, quickCount + 1)
    }

    func test_aFinalConnectionState_stopsTheSlowPhaseButNotTheQuickOne() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        for status in MoonPayTransactionPoller.finalConnectionStatuses {
            fetches = 0
            let poller = makePoller { fetch, _ in
                if fetch == 1 || fetch > quickCount { throw MoonPayRampError.verificationFailed(status) }
                return Self.details("pending")
            }

            let updates = await run(poller)

            XCTAssertEqual(updates, [.stillProcessing(transaction), .outcomeUnknown], "\(status)")
            XCTAssertEqual(fetches, quickCount + 1, "\(status)")
        }
    }

    func test_aConnectThatMayClear_backsOffInTheSlowPhase() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        let errors: [MoonPayRampError] = [.verificationFailed(.pending), .frame(.loadFailed("timed out"))]
        for error in errors {
            fetches = 0
            clock = Date(timeIntervalSince1970: 0)
            let poller = makePoller { fetch, _ in
                if fetch == quickCount + 1 { throw error }
                return fetch == quickCount + 2 ? Self.details("completed") : Self.details("pending")
            }

            let updates = await run(poller)

            XCTAssertEqual(updates, [
                .stillProcessing(transaction),
                .completed(MoonPayTransaction(id: "tx_1", status: "completed")),
            ], "\(error)")
            // Two slow intervals and one back-off after the first minute.
            XCTAssertEqual(clock.timeIntervalSince1970, 60 + 15 + 45 + 15, "\(error)")
        }
    }

    func test_aBackOff_endsAtTheDeadline() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        // The first slow poll succeeds, so the 60 s cycles that follow put the deadline 30 s into
        // a back-off: an uncapped back-off would overshoot it by 15 s.
        let poller = makePoller { fetch, _ in
            if fetch > quickCount + 1 { throw MoonPayRampError.verificationFailed(.pending) }
            return Self.details("pending")
        }

        let updates = await run(poller)

        XCTAssertEqual(updates, [.stillProcessing(transaction), .outcomeUnknown])
        XCTAssertEqual(clock.timeIntervalSince1970, 60 + MoonPayTransactionPoller.slowPollDuration)
    }

    func test_aClosedSignIn_stopsPolling() async {
        let poller = makePoller { _, _ in throw MoonPayRampError.verificationCancelled }

        let updates = await run(poller)

        XCTAssertEqual(updates, [.outcomeUnknown])
        XCTAssertEqual(fetches, 1)
    }

    func test_aSignInClosedInAnotherFlow_doesNotStopTheSlowPhase() async {
        let quickCount = MoonPayTransactionPoller.quickPollIntervals.count
        let poller = makePoller { fetch, _ in
            if fetch == quickCount + 1 { throw MoonPayRampError.verificationCancelled }
            return fetch == quickCount + 2 ? Self.details("completed") : Self.details("pending")
        }

        let updates = await run(poller)

        XCTAssertEqual(updates, [
            .stillProcessing(transaction),
            .completed(MoonPayTransaction(id: "tx_1", status: "completed")),
        ])
    }

    func test_anEndedStream_stopsPolling() async {
        let poller = makePoller { _, _ in Self.details("pending") }
        let (_, continuation) = AsyncStream<MoonPayPaymentUpdate>.makeStream()
        continuation.finish()

        await poller.poll(transaction: transaction, id: "tx_1", continuation: continuation)

        XCTAssertEqual(fetches, MoonPayTransactionPoller.quickPollIntervals.count)
    }

    private func makePoller(
        answer: @escaping (_ fetch: Int, _ allowsSignIn: Bool) throws -> MoonPayTransactionDetails
    ) -> MoonPayTransactionPoller {
        MoonPayTransactionPoller(
            fetch: { [unowned self] _, allowsSignIn in
                fetches += 1
                return try answer(fetches, allowsSignIn)
            },
            sleep: { [unowned self] nanoseconds in
                clock = clock.addingTimeInterval(TimeInterval(nanoseconds) / 1_000_000_000)
            },
            now: { [unowned self] in clock }
        )
    }

    private func run(_ poller: MoonPayTransactionPoller) async -> [MoonPayPaymentUpdate] {
        let (stream, continuation) = AsyncStream<MoonPayPaymentUpdate>.makeStream()
        await poller.poll(transaction: transaction, id: "tx_1", continuation: continuation)
        var updates: [MoonPayPaymentUpdate] = []
        for await update in stream {
            updates.append(update)
        }
        return updates
    }

    private static func details(_ status: String) -> MoonPayTransactionDetails {
        MoonPayTransactionDetails(id: "tx_1", status: status)
    }
}
