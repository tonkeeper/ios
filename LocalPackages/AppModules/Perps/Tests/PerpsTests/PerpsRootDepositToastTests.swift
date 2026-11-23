import Combine
@testable import Perps
import PerpsModels
import TKLocalize
import TKTestSupport
import XCTest

/// The row under the balance is read from the journal. A change is fed to `apply` directly:
/// the store observer only hops to the main actor before calling it.
@MainActor
final class PerpsRootDepositToastTests: XCTestCase {
    func testOneDepositShowsItsStepUntilItArrives() {
        let model = makeModel([deposit("a")])
        XCTAssertEqual(model.banner, .single("a"))

        var arrivals = 0
        model.onCompleted = { arrivals += 1 }
        model.apply([deposit("a", state: .completed, credited: "10")])

        XCTAssertEqual(model.banner, .completed(["a"]))
        XCTAssertEqual(arrivals, 1)
        XCTAssertEqual(model.completionText(["a"]), TKLocales.Perps.DepositStatus.addedToBalance("+$10"))

        model.apply([deposit("a", state: .completed, credited: "10")])
        XCTAssertEqual(model.banner, .completed(["a"]))
        XCTAssertEqual(arrivals, 1)
    }

    func testADepositCreditedBeforeTheScreenSawItIsNotAnnounced() {
        var arrivals = 0
        let model = makeModel([deposit("a", state: .completed, credited: "10")])
        model.onCompleted = { arrivals += 1 }

        model.apply([deposit("a", state: .completed, credited: "10")])

        XCTAssertNil(model.banner)
        XCTAssertEqual(arrivals, 0)
    }

    func testMultipleBecomesSingleWhenOnlyOneDepositIsPending() {
        let model = makeModel([deposit("a"), deposit("b"), deposit("c")])
        XCTAssertEqual(model.banner, .multiple)
        var arrivals = 0
        model.onCompleted = { arrivals += 1 }
        model.apply([deposit("b"), deposit("c"), deposit("a", state: .completed, credited: "4")])
        XCTAssertEqual(model.banner, .multiple)
        XCTAssertEqual(arrivals, 1)
        model.apply([deposit("c"), deposit("a", state: .completed, credited: "4"), deposit("b", state: .completed, credited: "6")])
        XCTAssertEqual(model.banner, .single("c"))
        model.apply([
            deposit("a", state: .completed, credited: "4"),
            deposit("b", state: .completed, credited: "6"),
            deposit("c", state: .completed, credited: "1"),
        ])
        XCTAssertEqual(model.banner, .completed(["c"]))
        XCTAssertEqual(model.completionText(["c"]), TKLocales.Perps.DepositStatus.addedToBalance("+$1"))
    }

    func testCompletionWaitsForTheBalanceRefresh() {
        let model = makeModel([deposit("a")])
        var arrivals = 0
        model.onCompleted = { arrivals += 1 }
        let credited = deposit("a", state: .completed, credited: "10")
        model.apply([credited], isBalanceRefreshing: true)
        XCTAssertEqual(model.banner, .single("a"))
        XCTAssertEqual(model.deposit("a")?.state, .pending)
        XCTAssertEqual(arrivals, 0)
        model.didInteract()
        XCTAssertEqual(model.banner, .single("a"))
        model.apply([credited])
        XCTAssertEqual(model.banner, .completed(["a"]))
        XCTAssertEqual(arrivals, 1)
    }

    func testUnknownCreditedAmountShowsTheExpectedAmountOnlyAsAnEstimate() {
        let unknown = deposit("a", state: .completed, expected: "10")
        let model = makeModel([unknown])
        XCTAssertEqual(model.completionText(["a"]), TKLocales.Perps.DepositStatus.completed)
        XCTAssertEqual(model.received(unknown), model.format.balance("10"))
        XCTAssertEqual(model.listedAmount(unknown).text, TKLocales.Perps.DepositStatus.approximateAmount(model.format.balance("10")))
        XCTAssertEqual(model.listedAmount(deposit("p", state: .pending, expected: "10")).text, model.format.balance("10"))
        XCTAssertFalse(model.listedAmount(unknown).positive)

        let credited = deposit("b", state: .completed, credited: "9.5", expected: "10")
        XCTAssertEqual(model.received(credited), model.format.balance("9.5"))
        XCTAssertTrue(model.listedAmount(credited).positive)
        XCTAssertEqual(model.received(deposit("c", state: .completed, expected: nil)), "—")
    }

    func testDepositsThatFinishTogetherSum() {
        let model = makeModel([deposit("a"), deposit("b")])
        model.apply([
            deposit("a", state: .completed, credited: "10"),
            deposit("b", state: .completed, credited: "2.5"),
        ])

        XCTAssertEqual(model.banner, .completed(["a", "b"]))
        XCTAssertEqual(model.completionText(["a", "b"]), TKLocales.Perps.DepositStatus.addedToBalance("+$12.50"))
    }

    func testAFailureStaysUntilTheSheetOpensAndALookAtThePendingOneDoesNotCount() {
        let model = makeModel([deposit("a")])
        model.didOpen("a")
        model.apply([deposit("a", state: .refunded, step: .sending)])

        XCTAssertEqual(model.banner, .single("a"))

        model.didOpen("a")
        XCTAssertNil(model.banner)
        model.apply([deposit("a", state: .refunded, step: .sending)])
        XCTAssertNil(model.banner)
    }

    func testMultipleDepositFailuresStayInTheList() {
        for state: PerpsDepositStatus.State in [.failed, .refunded, .unconfirmed] {
            let model = makeModel([deposit("a"), deposit("b")])
            model.apply([deposit("a", state: state), deposit("b")])
            XCTAssertEqual(model.banner, .single("b"))
            let ended = [deposit("a", state: state), deposit("b", state: state)]
            model.apply(ended)
            XCTAssertEqual(model.banner, .problems)
            model.didInteract()
            XCTAssertEqual(model.banner, .problems)
            XCTAssertEqual(model.deposits.count, 2)

            model.didOpenList()
            XCTAssertNil(model.banner)
            model.apply(ended)
            XCTAssertNil(model.banner)
            XCTAssertTrue(model.deposits.allSatisfy { $0.state == state })
        }
    }

    func testGroupedFailureRemainsAccessibleAfterTheOtherDepositCompletes() {
        let model = makeModel([deposit("a"), deposit("b")])
        model.apply([deposit("a", state: .failed), deposit("b", state: .completed, credited: "10")])
        XCTAssertEqual(model.banner, .completed(["b"]))
        model.didInteract()
        XCTAssertEqual(model.banner, .problems)
        model.didOpenList()
        XCTAssertNil(model.banner)
    }

    func testMultipleCompletionsKeepFailuresUntilTheListActuallyAppears() {
        let model = makeModel([deposit("a"), deposit("b"), deposit("c")])
        model.apply([
            deposit("a", state: .failed),
            deposit("b", state: .completed, credited: "10"),
            deposit("c", state: .completed, credited: "20"),
        ])
        XCTAssertEqual(model.banner, .completed(["b", "c"]))
        model.didInteract()
        XCTAssertEqual(model.banner, .problems)
        model.didOpenList()
        XCTAssertNil(model.banner)
    }

    func testAnOutcomeOpenedInHistoryStaysHiddenOnOtherScreensAndNewModels() async {
        for state: PerpsDepositStatus.State in [.failed, .refunded, .unconfirmed] {
            let store = StubRootAccountStore(activity: .init(deposits: [deposit("a", state: state)]))
            let root = PerpsDepositStatusViewModel(accountStore: store, format: .test)
            let history = PerpsDepositStatusViewModel(accountStore: store, format: .test)
            let hidden = expectation(description: "root observes acknowledgement from history")
            let observation = root.$banner.dropFirst().filter { $0 == nil }.sink { _ in hidden.fulfill() }
            history.didOpen("a")
            await fulfillment(of: [hidden], timeout: 2)
            XCTAssertNil(root.banner)
            XCTAssertNil(PerpsDepositStatusViewModel(accountStore: store, format: .test).banner)
            observation.cancel()
        }
    }

    func testOpeningTheListOnlyAcknowledgesFailuresAlreadyVisible() {
        let model = makeModel([deposit("a"), deposit("b")])
        model.didOpenList()
        model.apply([deposit("a", state: .failed), deposit("b")])
        model.didOpenList()
        XCTAssertEqual(model.banner, .single("b"))
        model.apply([deposit("a", state: .failed), deposit("b", state: .refunded)])
        XCTAssertEqual(model.banner, .problems)
        model.didOpenList()
        XCTAssertNil(model.banner)
    }

    func testAwayFromPerpsTheArrivalIsOnlyAnnounced() {
        let model = makeModel([deposit("a")])
        model.isVisible = false
        var arrivals = 0
        model.onCompleted = { arrivals += 1 }

        model.apply([deposit("a", state: .completed, credited: "10")])

        XCTAssertNil(model.banner)
        XCTAssertEqual(arrivals, 1)
    }

    func testTheCompletedRowLeavesOnTheNextAction() {
        let model = makeModel([deposit("a")])
        model.apply([deposit("a", state: .completed, credited: "10")])
        model.didInteract()
        XCTAssertNil(model.banner)
    }

    func testNoEstimateNeverCountsAsDelayed() {
        let now = Date(timeIntervalSince1970: 10000)
        let missing = deposit("a", createdAt: now.addingTimeInterval(-10000), estimated: nil)
        let waiting = deposit("a", createdAt: now.addingTimeInterval(-30), estimated: 120)
        let late = deposit("a", createdAt: now.addingTimeInterval(-121), estimated: 120)

        XCTAssertFalse(missing.isDelayed(at: now))
        XCTAssertFalse(waiting.isDelayed(at: now))
        XCTAssertTrue(late.isDelayed(at: now))
        XCTAssertFalse(deposit("a", state: .completed, createdAt: now.addingTimeInterval(-121), estimated: 120).isDelayed(at: now))
    }

    func testHiddenBalancesMaskTheAmounts() {
        let hidden = PerpsFormatting(amounts: PerpsTestAmountFormatting()) { "* * *" }
        let model = PerpsDepositStatusViewModel(
            accountStore: StubRootAccountStore(activity: PerpsFundingActivity(deposits: [deposit("a", credited: "10")])),
            format: hidden
        )
        XCTAssertEqual(model.amount(deposit("a")), "* * *")
        XCTAssertEqual(model.received(deposit("a", expected: "8")), "* * *")
        XCTAssertEqual(model.completionText(["a"]), TKLocales.Perps.DepositStatus.addedToBalance("* * *"))
    }

    /// The store announces a change every poll; re-setting an absent row would re-render the root each time.
    func testAnUnrelatedChangeDoesNotRepublishAnAbsentRow() {
        let model = makeModel([])
        var published = 0
        let cancellable = model.$banner.dropFirst().sink { _ in published += 1 }

        model.apply([])

        XCTAssertEqual(published, 0)
        withExtendedLifetime(cancellable) {}
    }

    func testACreditedDepositThatReadsInFlightAgainIsAnnouncedOnce() {
        let model = makeModel([deposit("a")])
        var arrivals = 0
        model.onCompleted = { arrivals += 1 }

        model.apply([deposit("a", state: .completed, credited: "10")])
        model.apply([deposit("a")])
        XCTAssertEqual(model.banner, .completed(["a"]))
        model.apply([deposit("a", state: .completed, credited: "10")])

        XCTAssertEqual(arrivals, 1)
        XCTAssertEqual(model.banner, .completed(["a"]))
    }

    func testTheCompletedRowLeavesByItself() async {
        let lifetime = CompletedRowLifetime()
        let model = makeModel([deposit("a")], lifetime: lifetime)
        model.apply([deposit("a", state: .completed, credited: "10")])
        XCTAssertEqual(model.banner, .completed(["a"]))
        await Task.yield()
        XCTAssertEqual(lifetime.started, 0)

        model.didShowBanner()
        await lifetime.waitUntilStarted(1)
        lifetime.end(0)

        await waitForBanner(model, nil)
    }

    func testANewCompletionRestartsTheCompletedRowLifetime() async {
        let lifetime = CompletedRowLifetime()
        let model = makeModel([deposit("a")], lifetime: lifetime)
        model.apply([deposit("a", state: .completed, credited: "10")])
        model.didShowBanner()
        model.apply([deposit("a", state: .completed, credited: "10"), deposit("b")])
        model.didShowBanner()
        model.apply([deposit("a", state: .completed, credited: "10"), deposit("b", state: .completed, credited: "5")])
        model.didShowBanner()
        XCTAssertEqual(model.banner, .completed(["b"]))

        await lifetime.waitUntilStarted(2)
        lifetime.endCancelled()
        await Task.yield()
        XCTAssertEqual(model.banner, .completed(["b"]))

        lifetime.end(0)
        await waitForBanner(model, nil)
    }

    func testAnEndedLifetimeDoesNotHideARowThatReplacedTheCompletedOne() async {
        let lifetime = CompletedRowLifetime()
        let model = makeModel([deposit("a")], lifetime: lifetime)
        model.apply([deposit("a", state: .completed, credited: "10")])
        model.didShowBanner()
        await lifetime.waitUntilStarted(1)

        model.apply([deposit("a", state: .completed, credited: "10"), deposit("b")])
        XCTAssertEqual(model.banner, .single("b"))
        lifetime.end(0)
        await Task.yield()

        XCTAssertEqual(model.banner, .single("b"))
    }

    func testTheListHidesDepositsSeenWhenItLastClosed() {
        let model = makeModel([
            deposit("a", state: .completed, credited: "10"),
            deposit("b"),
            deposit("c", state: .failed),
        ])
        XCTAssertEqual(model.didOpenList(), [])
        model.apply([
            deposit("a", state: .completed, credited: "10"),
            deposit("b", state: .completed, credited: "5"),
            deposit("c", state: .failed),
            deposit("d"),
        ])
        model.didCloseList()

        XCTAssertEqual(model.didOpenList(), ["a", "b", "c"])
        model.didCloseList()
        model.apply([
            deposit("a", state: .completed, credited: "10"),
            deposit("b", state: .completed, credited: "5"),
            deposit("c", state: .failed),
            deposit("d", state: .completed, credited: "1"),
        ])
        XCTAssertEqual(model.didOpenList(), ["a", "b", "c"])
    }

    func testTheListOpenedFromTheCompletedRowShowsTheDepositsItAnnounces() {
        let model = makeModel([deposit("a"), deposit("b")])
        model.didOpenList()
        model.apply([deposit("a", state: .completed, credited: "10"), deposit("b", state: .completed, credited: "5")])
        model.didCloseList()
        XCTAssertEqual(model.banner, .completed(["a", "b"]))

        model.didInteract()
        model.willOpenList(announcing: ["a", "b"])
        XCTAssertEqual(model.didOpenList(), [])
        model.didCloseList()
        XCTAssertEqual(model.didOpenList(), ["a", "b"])
    }

    func testListAcknowledgementsReachTheStore() {
        let store = StubRootAccountStore(activity: .init(deposits: [deposit("a", state: .completed, credited: "10"), deposit("b")]))
        let model = PerpsDepositStatusViewModel(accountStore: store, format: .test)
        model.didOpenList()
        model.didCloseList()

        XCTAssertEqual(store.fundingActivity().acknowledgedDepositIds, ["a"])
        XCTAssertEqual(PerpsDepositStatusViewModel(accountStore: store, format: .test).didOpenList(), ["a"])
    }

    private func waitForBanner(_ model: PerpsDepositStatusViewModel, _ banner: PerpsDepositStatusViewModel.Banner?) async {
        guard model.banner != banner else { return }
        let changed = expectation(description: "banner")
        let observation = model.$banner.filter { $0 == banner }.sink { _ in changed.fulfill() }
        await fulfillment(of: [changed], timeout: 2)
        observation.cancel()
    }

    private func makeModel(_ deposits: [PerpsDepositStatus], lifetime: CompletedRowLifetime? = nil) -> PerpsDepositStatusViewModel {
        let store = StubRootAccountStore(activity: PerpsFundingActivity(deposits: deposits))
        guard let lifetime else { return PerpsDepositStatusViewModel(accountStore: store, format: .test) }
        return PerpsDepositStatusViewModel(accountStore: store, format: .test) { await lifetime.run() }
    }

    private func deposit(
        _ id: String,
        state: PerpsDepositStatus.State = .pending,
        step: PerpsDepositStatus.Step? = .sending,
        createdAt: Date = Date(timeIntervalSince1970: 1000),
        estimated: Int? = 120,
        credited: String? = nil,
        expected: String? = "10"
    ) -> PerpsDepositStatus {
        PerpsDepositStatus(
            id: id,
            createdAt: createdAt,
            sourceAmount: "10",
            sourceSymbol: "TON",
            sourceNetwork: "ton",
            expectedAmount: expected,
            creditedAmount: credited,
            estimatedDurationSeconds: estimated,
            state: state,
            step: step
        )
    }
}

/// Each started lifetime waits until the test ends it, in start order.
@MainActor
private final class CompletedRowLifetime {
    private var waiters: [CheckedContinuation<Void, Never>?] = []
    private var cancelled: [CheckedContinuation<Void, Never>] = []

    func run() async {
        let isCancelled = Task.isCancelled
        await withCheckedContinuation { continuation in
            if isCancelled { cancelled.append(continuation) } else { waiters.append(continuation) }
        }
    }

    var started: Int {
        waiters.count + cancelled.count
    }

    func waitUntilStarted(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0 ..< 1000 where started < count {
            await Task.yield()
        }
        XCTAssertGreaterThanOrEqual(started, count, file: file, line: line)
    }

    func end(_ index: Int) {
        waiters[index]?.resume()
        waiters[index] = nil
    }

    func endCancelled() {
        cancelled.forEach { $0.resume() }
        cancelled = []
    }
}

final class StubRootAccountStore: PerpsAccountStoring {
    enum Call: Equatable {
        case refresh
        case loadMarketExtras(Int64)
    }

    var activity: PerpsFundingActivity

    init(activity: PerpsFundingActivity = PerpsFundingActivity()) {
        self.activity = activity
    }

    var state: PerpsWalletAccountState = .inactive
    var marketLifecycle: PerpsMarketLifecycle = .flat
    private(set) var positionsSubscribeCount = 0
    private(set) var positionsUnsubscribeCount = 0
    private(set) var extrasReleaseCount = 0
    private(set) var calls: [Call] = [] {
        didSet { callsChanged.send() }
    }

    let callsChanged = TestSignal()
    private var observers: [() -> Void] = []

    func addChangeObserver<T: AnyObject>(_ observer: T, onChange: @escaping (T) -> Void) {
        observers.append { [weak observer] in
            if let observer { onChange(observer) }
        }
    }

    func acknowledgeDepositStatuses(_ ids: Set<String>) {
        activity = PerpsFundingActivity(
            isBalanceRefreshing: activity.isBalanceRefreshing, deposits: activity.deposits,
            inFlight: activity.inFlight, pending: activity.pending, completed: activity.completed,
            failed: activity.failed, transactions: activity.transactions,
            acknowledgedDepositIds: activity.acknowledgedDepositIds.union(ids)
        )
        observers.forEach { $0() }
    }

    func currentWalletState() -> PerpsWalletAccountState {
        state
    }

    func resolveIfNeeded() {}
    func refresh() {
        calls.append(.refresh)
    }

    func fundingActivity() -> PerpsFundingActivity {
        activity
    }

    func lifecycle(marketId _: Int64) -> PerpsMarketLifecycle {
        marketLifecycle
    }

    func marketExtras(marketId _: Int64) -> PerpsMarketExtras? {
        nil
    }

    func loadMarketExtras(marketId: Int64) {
        calls.append(.loadMarketExtras(marketId))
    }

    func releaseMarketExtras(marketId _: Int64) {
        extrasReleaseCount += 1
    }

    func subscribePositions(cadence _: PerpsPositionsCadence) {
        positionsSubscribeCount += 1
    }

    func unsubscribePositions(cadence _: PerpsPositionsCadence) {
        positionsUnsubscribeCount += 1
    }
}

/// The synchronous store port reads the mutable test state and counters under the lock.
final class StubRootMarketsStore: PerpsMarketsStoring, @unchecked Sendable {
    private final class NoInterest: PerpsPriceInteresting {
        func set(marketIds _: Set<Int64>) {}
        func clear() {}
    }

    private let lock = NSLock()
    private var storedMarkets: PerpsMarkets?
    private var subscribes = 0
    private var unsubscribes = 0

    var markets: PerpsMarkets? {
        get { lock.withLock { storedMarkets } }
        set { lock.withLock { storedMarkets = newValue } }
    }

    var subscribeCount: Int {
        lock.withLock { subscribes }
    }

    var unsubscribeCount: Int {
        lock.withLock { unsubscribes }
    }

    init(markets: PerpsMarkets? = nil) {
        storedMarkets = markets
    }

    func addChangeObserver<T: AnyObject>(_: T, onChange _: @escaping (T) -> Void) {}
    func getState() -> PerpsMarketsState {
        markets.map(PerpsMarketsState.loaded) ?? .idle
    }

    func subscribe() {
        lock.withLock { subscribes += 1 }
    }

    func unsubscribe() {
        lock.withLock { unsubscribes += 1 }
    }

    func setSort(_: PerpsMarketsSort) {}
    func loadNextPage() {}
    func makePriceInterest() -> any PerpsPriceInteresting {
        NoInterest()
    }

    func price(marketId _: Int64) async -> Double? {
        nil
    }

    func snapshot(marketId _: Int64) async -> PerpsAssetMarketSnapshot? {
        nil
    }
}
