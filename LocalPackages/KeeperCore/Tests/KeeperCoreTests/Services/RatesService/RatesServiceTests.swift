import Foundation
@testable import KeeperCore
import XCTest

final class RatesServiceFreshnessTests: XCTestCase {
    /// TK-2837: migrating a 50+ asset wallet produced a streaming update every couple of seconds,
    /// and every one of them fired its own `/v2/rates`.
    func test_burstOfSequentialCallsProducesOneRequest() async throws {
        let fetch = ControlledRatesFetch()
        let service = makeService(fetch: fetch)

        for _ in 0 ..< 25 {
            fetch.completeNextLoadImmediately()
            _ = try await service.loadRates(jettons: [], currencies: [.USD])
        }

        XCTAssertEqual(fetch.startedCount, 1)
    }

    func test_concurrentCallersShareOneRequest() async throws {
        let fetch = ControlledRatesFetch()
        let service = makeService(fetch: fetch)

        let started = expectation(description: "request started")
        fetch.didStartLoad = { started.fulfill() }
        let callers = (0 ..< 5).map { _ in
            Task { try await service.loadRates(jettons: [], currencies: [.USD]) }
        }
        await fulfillment(of: [started], timeout: 1)

        fetch.completeLoad(tonRate: 3)
        for caller in callers {
            let rates = try await caller.value
            XCTAssertEqual(rates.ton.first?.rate, 3)
        }
        XCTAssertEqual(fetch.startedCount, 1)
    }

    private func makeService(
        fetch: ControlledRatesFetch,
        clock: ControlledClock = ControlledClock()
    ) -> RatesService {
        RatesServiceImplementation(
            fetchRates: { try await fetch.fetch(jettons: $0, currencies: $1) },
            ratesRepository: StubRatesRepository(),
            freshnessInterval: 30,
            failureRetryInterval: 5,
            now: { clock.now() }
        )
    }
}

final class RatesServiceScopeTests: XCTestCase {
    func test_differentJettonSetIsNotServedFromAnotherScope() async throws {
        let fetch = ControlledRatesFetch()
        let service = makeService(fetch: fetch)

        fetch.completeNextLoadImmediately()
        _ = try await service.loadRates(jettons: ["USDT"], currencies: [.USD])
        fetch.completeNextLoadImmediately()
        _ = try await service.loadRates(jettons: ["TRX"], currencies: [.USD])

        XCTAssertEqual(fetch.startedCount, 2)
    }

    private func makeService(fetch: ControlledRatesFetch) -> RatesService {
        RatesServiceImplementation(
            fetchRates: { try await fetch.fetch(jettons: $0, currencies: $1) },
            ratesRepository: StubRatesRepository(),
            now: { Date(timeIntervalSince1970: 0) }
        )
    }
}

final class RatesServiceFailureTests: XCTestCase {
    func test_failureKeepsServingThePreviousPayload() async throws {
        let fetch = ControlledRatesFetch()
        let clock = ControlledClock()
        let service = makeService(fetch: fetch, clock: clock)

        fetch.completeNextLoadImmediately(tonRate: 5)
        _ = try await service.loadRates(jettons: [], currencies: [.USD])
        clock.advance(by: 30)
        fetch.failNextLoadImmediately()

        let rates = try await service.loadRates(jettons: [], currencies: [.USD])
        XCTAssertEqual(rates.ton.first?.rate, 5)
    }

    private func makeService(
        fetch: ControlledRatesFetch,
        clock: ControlledClock = ControlledClock()
    ) -> RatesService {
        RatesServiceImplementation(
            fetchRates: { try await fetch.fetch(jettons: $0, currencies: $1) },
            ratesRepository: StubRatesRepository(),
            freshnessInterval: 30,
            failureRetryInterval: 5,
            now: { clock.now() }
        )
    }
}

private final class ControlledRatesFetch: @unchecked Sendable {
    var didStartLoad: (() -> Void)?

    private struct Pending {
        let continuation: CheckedContinuation<Rates, Error>
    }

    private enum Immediate {
        case success(Decimal)
        case failure
    }

    private let ignoresCancellation: Bool
    private let lock = NSLock()
    private var pending = [Pending]()
    private var immediate = [Immediate]()
    private var started = 0
    private var cancelled = 0

    var startedCount: Int {
        lock.withLock { started }
    }

    var cancelledCount: Int {
        lock.withLock { cancelled }
    }

    init(ignoresCancellation: Bool = false) {
        self.ignoresCancellation = ignoresCancellation
    }

    /// Arms the next request to settle without the test having to interleave a `completeLoad`.
    func completeNextLoadImmediately(tonRate: Decimal = 1) {
        lock.withLock { immediate.append(.success(tonRate)) }
    }

    func failNextLoadImmediately() {
        lock.withLock { immediate.append(.failure) }
    }

    func fetch(jettons _: [String], currencies _: [Currency]) async throws -> Rates {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Rates, Error>) in
                let outcome = lock.withLock { () -> (Immediate?, (() -> Void)?) in
                    started += 1
                    let immediate = self.immediate.isEmpty ? nil : self.immediate.removeFirst()
                    if immediate == nil {
                        pending.append(Pending(continuation: continuation))
                    }
                    return (immediate, didStartLoad)
                }
                outcome.1?()
                switch outcome.0 {
                case let .success(tonRate):
                    continuation.resume(returning: Self.makeRates(tonRate: tonRate))
                case .failure:
                    continuation.resume(throwing: LoadFailure())
                case nil:
                    break
                }
            }
        } onCancel: {
            let shouldResume = lock.withLock {
                cancelled += 1
                return !ignoresCancellation
            }
            if shouldResume {
                resumeNext(with: .failure(CancellationError()))
            }
        }
    }

    func completeLoad(tonRate: Decimal = 1) {
        resumeNext(with: .success(Self.makeRates(tonRate: tonRate)))
    }

    private func resumeNext(with result: Result<Rates, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<Rates, Error>? in
            pending.isEmpty ? nil : pending.removeFirst().continuation
        }
        continuation?.resume(with: result)
    }

    private static func makeRates(tonRate: Decimal) -> Rates {
        Rates(
            ton: [Rates.Rate(currency: .USD, rate: tonRate, diff24h: nil)],
            usdt: [],
            jettonRates: [:]
        )
    }

    private struct LoadFailure: Error {}
}

private final class ControlledClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 0)

    func now() -> Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            date = date.addingTimeInterval(interval)
        }
    }
}

private struct StubRatesRepository: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        Rates(ton: [], usdt: [], jettonRates: [:])
    }
}
