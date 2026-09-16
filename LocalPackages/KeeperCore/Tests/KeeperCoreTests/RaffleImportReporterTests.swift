import Foundation
@testable import KeeperCore
import XCTest

/// The import task pays the wallet it was started from, so the pair (source wallet, imported
/// wallet) has to survive the import flow and every way it can fail to reach the backend on the
/// first pass: a wallet that is not registered yet, and a request that does not go through.
final class RaffleImportReporterTests: XCTestCase {
    private var suiteName = ""
    private var userDefaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        suiteName = "RaffleImportReporterTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_deliversThePairOnceAndForgetsIt() async {
        let backend = MarkImportRecorder()
        let reporter = makeReporter(registered: ["local-1": "imported-wallet-id"], backend: backend)

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await reporter.recordImported(walletIds: ["local-1"])
        await reporter.flush()

        let calls = await backend.calls
        XCTAssertEqual(calls, [Call(walletId: "source-wallet-id", importedWalletId: "imported-wallet-id")])
    }

    /// An import the user reached on their own is not a raffle task.
    func test_importWithoutATaskIsNotReported() async {
        let backend = MarkImportRecorder()
        let reporter = makeReporter(registered: ["local-1": "imported-wallet-id"], backend: backend)

        await reporter.recordImported(walletIds: ["local-1"])
        await reporter.flush()

        let calls = await backend.calls
        XCTAssertTrue(calls.isEmpty)
    }

    /// Re-importing the wallet the task was started from earns nothing.
    func test_reimportingTheSourceWalletIsNotReported() async {
        let backend = MarkImportRecorder()
        let reporter = makeReporter(registered: ["local-1": "source-wallet-id"], backend: backend)

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await reporter.recordImported(walletIds: ["local-1"])

        let calls = await backend.calls
        XCTAssertTrue(calls.isEmpty)
    }

    /// The sync that registers the wallet can fail during the import: the pair waits for the id
    /// instead of being dropped, and the next pass delivers it.
    func test_unregisteredImportIsDeliveredOnceItRegisters() async {
        let backend = MarkImportRecorder()
        let registry = WalletRegistry()
        let reporter = makeReporter(registry: registry, backend: backend)

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await reporter.recordImported(walletIds: ["local-1"])
        var calls = await backend.calls
        XCTAssertTrue(calls.isEmpty)

        registry.registered = ["local-1": "imported-wallet-id"]
        await reporter.flush()

        calls = await backend.calls
        XCTAssertEqual(calls, [Call(walletId: "source-wallet-id", importedWalletId: "imported-wallet-id")])
    }

    func test_aFailedRequestIsRetriedOnTheNextFlush() async {
        let backend = MarkImportRecorder(failures: MultichainRetry.defaultAttempts)
        let reporter = makeReporter(registered: ["local-1": "imported-wallet-id"], backend: backend)

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await reporter.recordImported(walletIds: ["local-1"])
        var attempts = await backend.attempts
        var calls = await backend.calls
        XCTAssertEqual(attempts, MultichainRetry.defaultAttempts)
        XCTAssertTrue(calls.isEmpty)

        await reporter.flush()
        attempts = await backend.attempts
        calls = await backend.calls
        XCTAssertEqual(attempts, MultichainRetry.defaultAttempts + 1)
        XCTAssertEqual(calls, [Call(walletId: "source-wallet-id", importedWalletId: "imported-wallet-id")])

        // Delivered — nothing is left to retry.
        await reporter.flush()
        attempts = await backend.attempts
        XCTAssertEqual(attempts, MultichainRetry.defaultAttempts + 1)
    }

    func test_aTaskTheUserNeverFinishedExpires() async {
        let backend = MarkImportRecorder()
        let clock = TestClock(now: Date(timeIntervalSince1970: 0))
        let reporter = makeReporter(
            registered: ["local-1": "imported-wallet-id"],
            backend: backend,
            clock: clock
        )

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        clock.now = Date(timeIntervalSince1970: 8 * 24 * 60 * 60)
        await reporter.recordImported(walletIds: ["local-1"])

        let calls = await backend.calls
        XCTAssertTrue(calls.isEmpty)
    }

    /// A second import under the same task replaces the first: the task pays once.
    func test_aLaterImportReplacesAnUndeliveredOne() async {
        let backend = MarkImportRecorder()
        let registry = WalletRegistry(registered: ["local-2": "second-wallet-id"])
        let reporter = makeReporter(registry: registry, backend: backend)

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await reporter.recordImported(walletIds: ["local-1"])
        await reporter.recordImported(walletIds: ["local-2"])

        let calls = await backend.calls
        XCTAssertEqual(calls, [Call(walletId: "source-wallet-id", importedWalletId: "second-wallet-id")])
    }

    /// A status the backend chose repeats identically, so a rejected pair gets a few passes and is
    /// then dropped instead of sending the same doomed request for the whole TTL.
    func test_aRejectedPairStopsAfterItsPasses() async {
        let backend = MarkImportRecorder(rejectEverything: true)
        let reporter = makeReporter(registered: ["local-1": "imported-wallet-id"], backend: backend)

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await reporter.recordImported(walletIds: ["local-1"])
        for _ in 0 ..< 10 {
            await reporter.flush()
        }

        let attempts = await backend.attempts
        XCTAssertEqual(attempts, 5)
    }

    /// A pass that never reached the backend costs the record nothing: it is the case retrying is
    /// unambiguously right for.
    func test_anUnreachableBackendDoesNotSpendThePasses() async {
        let backend = MarkImportRecorder(failures: .max)
        let reporter = makeReporter(registered: ["local-1": "imported-wallet-id"], backend: backend)

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await reporter.recordImported(walletIds: ["local-1"])
        for _ in 0 ..< 10 {
            await reporter.flush()
        }

        // Every pass burns the retry ladder, and the record is still there to try again.
        let attempts = await backend.attempts
        XCTAssertEqual(attempts, 11 * MultichainRetry.defaultAttempts)
    }

    /// Each source wallet runs the task on its own, so a pair the backend has not taken yet must
    /// survive another wallet starting the same task.
    func test_aSecondWalletsTaskKeepsTheFirstsUndeliveredPair() async {
        let backend = MarkImportRecorder(failures: MultichainRetry.defaultAttempts)
        let reporter = makeReporter(
            registered: ["local-1": "first-imported-id", "local-2": "second-imported-id"],
            backend: backend
        )

        await reporter.beginImport(sourceWalletId: "first-source-id")
        // Exhausts the retry budget, leaving the pair undelivered.
        await reporter.recordImported(walletIds: ["local-1"])

        await reporter.beginImport(sourceWalletId: "second-source-id")
        await reporter.recordImported(walletIds: ["local-2"])

        let calls = await backend.calls
        XCTAssertTrue(calls.contains(Call(walletId: "first-source-id", importedWalletId: "first-imported-id")))
        XCTAssertTrue(calls.contains(Call(walletId: "second-source-id", importedWalletId: "second-imported-id")))

        // Both delivered — nothing is left to retry.
        await reporter.flush()
        let callsAfterFlush = await backend.calls
        XCTAssertEqual(callsAfterFlush.count, calls.count)
    }

    /// The actor is reentrant across the request, so a task restarted while an older delivery was
    /// still out must not be dropped by that delivery's success.
    func test_aDeliveryInFlightKeepsARestartedTask() async {
        let gate = Gate()
        let backend = MarkImportRecorder(pauseFirstCallUntil: gate)
        let reporter = makeReporter(
            registered: ["local-1": "first-imported-id", "local-2": "second-imported-id"],
            backend: backend
        )

        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        let delivery = Task { await reporter.recordImported(walletIds: ["local-1"]) }
        await backend.waitUntilFirstCallStarted()

        // Restarted while the first request is still out.
        await reporter.beginImport(sourceWalletId: "source-wallet-id")
        await gate.open()
        await delivery.value

        await reporter.recordImported(walletIds: ["local-2"])

        let calls = await backend.calls
        XCTAssertEqual(calls, [
            Call(walletId: "source-wallet-id", importedWalletId: "first-imported-id"),
            Call(walletId: "source-wallet-id", importedWalletId: "second-imported-id"),
        ])
    }
}

private extension RaffleImportReporterTests {
    func makeReporter(
        registered: [String: String] = [:],
        backend: MarkImportRecorder,
        clock: TestClock = TestClock(now: Date(timeIntervalSince1970: 0))
    ) -> RaffleImportReporter {
        makeReporter(registry: WalletRegistry(registered: registered), backend: backend, clock: clock)
    }

    func makeReporter(
        registry: WalletRegistry,
        backend: MarkImportRecorder,
        clock: TestClock = TestClock(now: Date(timeIntervalSince1970: 0))
    ) -> RaffleImportReporter {
        RaffleImportReporter(
            userDefaults: userDefaults,
            now: { clock.now },
            sleep: { _ in },
            resolveRegisteredWalletId: { registry.registered[$0] },
            markImport: { walletId, importedWalletId throws(MultichainServiceError) in
                try await backend.markImport(walletId: walletId, importedWalletId: importedWalletId)
            }
        )
    }
}

private struct Call: Equatable {
    let walletId: String
    let importedWalletId: String
}

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private final class WalletRegistry: @unchecked Sendable {
    var registered: [String: String]

    init(registered: [String: String] = [:]) {
        self.registered = registered
    }
}

private actor MarkImportRecorder {
    /// Pairs the backend accepted, not the requests that were made — a failed attempt is not a
    /// delivery, and a test asserting on one would pass without the record ever getting through.
    private(set) var calls = [Call]()
    private(set) var attempts = 0
    private var remainingFailures: Int
    /// Parks the first call, so a test can act inside the reporter's reentrancy window.
    private let pauseFirstCallUntil: Gate?
    private let firstCallStarted = Gate()
    private var didPause = false
    /// Answers with a status of its own, the way a 400/403/404 would.
    private let rejectEverything: Bool

    init(failures: Int = 0, rejectEverything: Bool = false, pauseFirstCallUntil: Gate? = nil) {
        remainingFailures = failures
        self.rejectEverything = rejectEverything
        self.pauseFirstCallUntil = pauseFirstCallUntil
    }

    func waitUntilFirstCallStarted() async {
        await firstCallStarted.wait()
    }

    func markImport(walletId: String, importedWalletId: String) async throws(MultichainServiceError) {
        attempts += 1
        if let pauseFirstCallUntil, !didPause {
            didPause = true
            await firstCallStarted.open()
            await pauseFirstCallUntil.wait()
        }
        if rejectEverything {
            throw .apiError(message: "rejected")
        }
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw .connectionError
        }
        calls.append(Call(walletId: walletId, importedWalletId: importedWalletId))
    }
}

/// One-shot latch: `wait()` returns once `open()` has been called, before or after.
private actor Gate {
    private var isOpen = false
    private var waiters = [CheckedContinuation<Void, Never>]()

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let resumed = waiters
        waiters.removeAll()
        resumed.forEach { $0.resume() }
    }
}
