import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class HistoryPaginationLoaderReloadDecisionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100)

    func test_firstReloadStartsImmediately() {
        XCTAssertEqual(makeDecision(lastReloadDate: nil), .start)
    }

    func test_reloadAfterIntervalStartsImmediately() {
        XCTAssertEqual(makeDecision(lastReloadDate: now.addingTimeInterval(-1)), .start)
    }

    func test_reloadWithinIntervalIsDeferredByRemainingTime() {
        XCTAssertEqual(makeDecision(lastReloadDate: now.addingTimeInterval(-0.25)), .schedule(after: 0.75))
    }

    func test_reloadInFlightCoalescesIntoSingleFollowUp() {
        XCTAssertEqual(
            makeDecision(isReloadInFlight: true, lastReloadDate: now.addingTimeInterval(-5)),
            .coalesce
        )
    }

    func test_alreadyScheduledReloadSwallowsFurtherTriggers() {
        XCTAssertEqual(
            makeDecision(isReloadScheduled: true, lastReloadDate: now.addingTimeInterval(-0.25)),
            .skip
        )
    }

    func test_retryDelayIsHonouredAfterThrottleElapsed() {
        XCTAssertEqual(
            makeDecision(lastReloadDate: now.addingTimeInterval(-5), minimumDelay: 2),
            .schedule(after: 2)
        )
    }

    func test_throttleWinsOverShorterRetryDelay() {
        XCTAssertEqual(
            makeDecision(lastReloadDate: now.addingTimeInterval(-0.25), minimumDelay: 0.5),
            .schedule(after: 0.75)
        )
    }

    private func makeDecision(
        isReloadInFlight: Bool = false,
        isReloadScheduled: Bool = false,
        lastReloadDate: Date?,
        minimumDelay: TimeInterval = 0
    ) -> HistoryPaginationLoader.ReloadDecision {
        HistoryPaginationLoader.reloadDecision(
            isReloadInFlight: isReloadInFlight,
            isReloadScheduled: isReloadScheduled,
            lastReloadDate: lastReloadDate,
            now: now,
            minInterval: 1,
            minimumDelay: minimumDelay
        )
    }
}

final class HistoryPaginationLoaderReloadCoalescingTests: XCTestCase {
    func test_burstDuringRequestInFlightProducesSingleFollowUpRequest() async {
        let loader = ControlledHistoryListLoader()
        let paginationLoader = makePaginationLoader(loader: loader)

        let firstRequest = expectation(description: "first request started")
        loader.didStartLoad = { firstRequest.fulfill() }
        await paginationLoader.reload(reason: .refresh)
        await fulfillment(of: [firstRequest], timeout: 1)

        let followUpRequest = expectation(description: "follow up request started")
        loader.didStartLoad = { followUpRequest.fulfill() }
        for _ in 0 ..< 30 {
            await paginationLoader.reload(reason: .refresh)
        }
        XCTAssertEqual(loader.startedCount, 1, "background updates must not restart a request in flight")

        loader.completeLoad()
        await fulfillment(of: [followUpRequest], timeout: 1)

        XCTAssertEqual(loader.startedCount, 2)
        XCTAssertEqual(loader.cancelledCount, 0)

        loader.completeLoad()
    }

    func test_immediateReloadRestartsRequestInFlight() async {
        let loader = ControlledHistoryListLoader()
        let paginationLoader = makePaginationLoader(loader: loader)

        let firstRequest = expectation(description: "first request started")
        loader.didStartLoad = { firstRequest.fulfill() }
        await paginationLoader.reload(reason: .refresh)
        await fulfillment(of: [firstRequest], timeout: 1)

        let forcedRequest = expectation(description: "forced request started")
        loader.didStartLoad = { forcedRequest.fulfill() }
        await paginationLoader.reload(reason: .immediate)
        await fulfillment(of: [forcedRequest], timeout: 1)

        XCTAssertEqual(loader.startedCount, 2)
        XCTAssertEqual(loader.cancelledCount, 1)

        loader.completeLoad()
    }

    func test_cancelledLoadCannotPublishStaleCompletion() async {
        let loader = ControlledHistoryListLoader(ignoresCancellation: true)
        let paginationLoader = makePaginationLoader(loader: loader)

        await startRequest(loader: loader) {
            await paginationLoader.reload(reason: .refresh)
        }
        await startRequest(loader: loader) {
            await paginationLoader.reload(reason: .immediate)
        }

        loader.completeLoad(headEventId: "stale-event")
        await Task.yield()
        loader.completeLoad(headEventId: "fresh-event")

        for await event in paginationLoader.events {
            guard case let .initialLoaded(events, _) = event else { continue }
            XCTAssertEqual(events.map(\.eventId), ["fresh-event"])
            return
        }
    }

    func test_cancelledScheduledTaskCannotConsumeReplacementSchedule() async {
        let loader = ControlledHistoryListLoader()
        let sleeper = ControlledSleeper()
        let clock = ControlledClock()
        let paginationLoader = makePaginationLoader(
            loader: loader,
            minReloadInterval: 60,
            sleep: { try await sleeper.sleep(delay: $0) },
            now: { clock.now() }
        )

        await startRequest(loader: loader) {
            await paginationLoader.reload(reason: .immediate)
        }
        await completeRequest(loader: loader, paginationLoader: paginationLoader)

        await scheduleReload(sleeper: sleeper) {
            await paginationLoader.reload(reason: .refresh)
        }

        await startRequest(loader: loader) {
            await paginationLoader.reload(reason: .immediate)
        }
        await completeRequest(loader: loader, paginationLoader: paginationLoader)

        await scheduleReload(sleeper: sleeper) {
            await paginationLoader.reload(reason: .refresh)
        }

        clock.advance(by: 60)

        let staleCallbackStartedRequest = expectation(description: "stale callback started request")
        staleCallbackStartedRequest.isInverted = true
        loader.didStartLoad = { staleCallbackStartedRequest.fulfill() }
        sleeper.resumeNext()
        await fulfillment(of: [staleCallbackStartedRequest], timeout: 0.1)

        let replacementRequest = expectation(description: "replacement request started")
        loader.didStartLoad = { replacementRequest.fulfill() }
        sleeper.resumeNext()
        await fulfillment(of: [replacementRequest], timeout: 1)

        XCTAssertEqual(loader.startedCount, 3)
        loader.completeLoad()
    }

    private func makePaginationLoader(
        loader: HistoryListLoader,
        minReloadInterval: TimeInterval = 0,
        sleep: @escaping HistoryPaginationLoader.Sleep = HistoryPaginationLoader.defaultSleep,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> HistoryPaginationLoader {
        HistoryPaginationLoader(
            wallet: .testWallet,
            loader: loader,
            nftService: StubNFTService(),
            minReloadInterval: minReloadInterval,
            sleep: sleep,
            now: now
        )
    }

    private func startRequest(
        loader: ControlledHistoryListLoader,
        trigger: () async -> Void
    ) async {
        let request = expectation(description: "request started")
        loader.didStartLoad = { request.fulfill() }
        await trigger()
        await fulfillment(of: [request], timeout: 1)
    }

    private func completeRequest(
        loader: ControlledHistoryListLoader,
        paginationLoader: HistoryPaginationLoader
    ) async {
        loader.completeLoad()
        for await event in paginationLoader.events {
            if case .initialLoaded = event {
                return
            }
        }
    }

    private func scheduleReload(
        sleeper: ControlledSleeper,
        trigger: () async -> Void
    ) async {
        let scheduled = expectation(description: "reload scheduled")
        sleeper.onNextSleep { scheduled.fulfill() }
        await trigger()
        await fulfillment(of: [scheduled], timeout: 1)
    }
}

/// Indexing lags a couple of seconds behind the streaming notification, so a reload triggered by it
/// uses a bounded retry sequence that does not rely on unrelated history changes.
final class HistoryPaginationLoaderStreamingRetryTests: XCTestCase {
    private let loader = ControlledHistoryListLoader()
    private var paginationLoader: HistoryPaginationLoader!
    private var onRequestStarted: (() -> Void)?

    override func setUp() {
        super.setUp()
        paginationLoader = HistoryPaginationLoader(
            wallet: .testWallet,
            loader: loader,
            nftService: StubNFTService(),
            minReloadInterval: 0
        )
        loader.didStartLoad = { [unowned self] in onRequestStarted?() }
    }

    func test_headChangeDoesNotStopBoundedRetriesEarly() async {
        await loadBaseline()
        await startRequest { await paginationLoader.reload(reason: .streamingUpdate) }

        await completeRequest(headEventId: .baselineEventId, expectingFurtherRequest: true)
        await completeRequest(headEventId: "unrelated-event", expectingFurtherRequest: true)
        await completeRequest(headEventId: "unrelated-event", expectingFurtherRequest: true)
        await completeRequest(headEventId: "unrelated-event", expectingFurtherRequest: false)

        XCTAssertEqual(loader.startedCount, 5)
    }

    func test_retriesStopWhenBudgetIsExhausted() async {
        await loadBaseline()
        await startRequest { await paginationLoader.reload(reason: .streamingUpdate) }

        for _ in 0 ..< 3 {
            await completeRequest(headEventId: .baselineEventId, expectingFurtherRequest: true)
        }
        await completeRequest(headEventId: .baselineEventId, expectingFurtherRequest: false)

        XCTAssertEqual(loader.startedCount, 5, "one reload plus three retries on top of the baseline load")
    }

    func test_streamingUpdateDuringReloadStartsOnlyThreeBackoffRequests() async {
        await startRequest { await paginationLoader.reload(reason: .immediate) }
        await paginationLoader.reload(reason: .streamingUpdate)

        for _ in 0 ..< 3 {
            await completeRequest(headEventId: .baselineEventId, expectingFurtherRequest: true)
        }
        await completeRequest(headEventId: .baselineEventId, expectingFurtherRequest: false)

        XCTAssertEqual(loader.startedCount, 4, "the in-flight reload is followed by three backoff requests")
    }

    private func loadBaseline() async {
        await startRequest { await paginationLoader.reload(reason: .immediate) }
        await completeRequest(headEventId: .baselineEventId, expectingFurtherRequest: false)
    }

    private func startRequest(_ trigger: () async -> Void) async {
        let started = expectation(description: "request started")
        onRequestStarted = { started.fulfill() }
        await trigger()
        await fulfillment(of: [started], timeout: 1)
    }

    /// Arms the next-request expectation before completing, so a retry cannot slip through unseen.
    private func completeRequest(headEventId: String, expectingFurtherRequest: Bool) async {
        let nextRequest = expectation(description: "further request started")
        nextRequest.isInverted = !expectingFurtherRequest
        onRequestStarted = { nextRequest.fulfill() }
        loader.completeLoad(headEventId: headEventId)
        await fulfillment(of: [nextRequest], timeout: expectingFurtherRequest ? 1 : 0.2)
    }
}

private final class ControlledSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [CheckedContinuation<Void, Never>]()
    private var nextSleepHandler: (() -> Void)?

    func sleep(delay _: TimeInterval) async throws {
        await withCheckedContinuation { continuation in
            let handler = lock.withLock { () -> (() -> Void)? in
                continuations.append(continuation)
                defer { nextSleepHandler = nil }
                return nextSleepHandler
            }
            handler?()
        }
    }

    func onNextSleep(_ handler: @escaping () -> Void) {
        lock.withLock {
            nextSleepHandler = handler
        }
    }

    func resumeNext() {
        let continuation = lock.withLock { continuations.removeFirst() }
        continuation.resume()
    }
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

/// Suspends every load until the test resumes it, so reload wiring is driven by observed requests
/// instead of wall-clock waits.
private final class ControlledHistoryListLoader: HistoryListLoader, @unchecked Sendable {
    var didStartLoad: (() -> Void)?

    private let ignoresCancellation: Bool
    private let lock = NSLock()
    private var continuations = [CheckedContinuation<HistoryEventsBatch, Error>]()
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

    func loadEvents(
        wallet _: Wallet,
        pagination _: HistoryListLoaderPagination,
        limit _: Int
    ) async throws -> HistoryEventsBatch {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
                HistoryEventsBatch,
                Error
            >) in
                let didStartLoad = lock.withLock { () -> (() -> Void)? in
                    continuations.append(continuation)
                    started += 1
                    return self.didStartLoad
                }
                didStartLoad?()
            }
        } onCancel: {
            let shouldResume = lock.withLock {
                cancelled += 1
                return !ignoresCancellation
            }
            if shouldResume {
                resumeNextContinuation(with: .failure(CancellationError()))
            }
        }
    }

    func completeLoad(headEventId: String? = nil) {
        resumeNextContinuation(with: .success(Self.makeBatch(headEventId: headEventId)))
    }

    private func resumeNextContinuation(with result: Result<HistoryEventsBatch, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<HistoryEventsBatch, Error>? in
            continuations.isEmpty ? nil : continuations.removeFirst()
        }
        continuation?.resume(with: result)
    }

    private static func makeBatch(headEventId: String?) -> HistoryEventsBatch {
        guard let headEventId else {
            return HistoryEventsBatch(accountsEvents: nil, tronTransactions: nil)
        }
        let event = AccountEvent(
            eventId: headEventId,
            date: Date(timeIntervalSince1970: 0),
            account: WalletAccount(address: .testAddress, name: nil, isScam: false, isWallet: true),
            isScam: false,
            isInProgress: false,
            extra: .Fee(0),
            excess: nil,
            progress: nil,
            actions: []
        )
        return HistoryEventsBatch(
            accountsEvents: AccountEvents(
                address: .testAddress,
                events: [event],
                startFrom: 0,
                nextFrom: 0
            ),
            tronTransactions: nil
        )
    }
}

private struct StubNFTService: NFTService {
    func loadNFTs(addresses _: [Address], network _: Network) async throws -> [Address: NFT] {
        [:]
    }

    func getNFT(address _: Address, network _: Network) throws -> NFT {
        throw StubError()
    }

    func saveNFT(nft _: NFT, network _: Network) throws {}
    func changeSuspiciousState(_: NFT, network _: Network, isScam _: Bool) async throws {}

    private struct StubError: Error {}
}

private extension String {
    static let baselineEventId = "baseline-event"
}

private extension Address {
    static let testAddress = try! Address.parse(
        "0:9d6a9b06892647479477db8684a0aba15468fc70afe30f5117be35d6c7326087"
    )
}

private extension Wallet {
    static let testWallet: Wallet = {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "history-pagination-loader-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }()
}
