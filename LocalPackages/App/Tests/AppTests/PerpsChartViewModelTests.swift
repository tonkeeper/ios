@testable import App
@testable import KeeperCore
import XCTest

final class PerpsChartViewModelTests: XCTestCase {
    @MainActor
    func test_watchLifecycle_appliesInitialAndLiveFramesThenCancels() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake)

        viewModel.onAppear()

        await waitUntil { viewModel.loadingState == .ready }
        XCTAssertEqual(viewModel.candles.count, 3)
        XCTAssertEqual(viewModel.snapshot?.timeframe, .h1)

        fake.emitUpdate(makeSnapshot(timeframe: .h1, count: 5))
        await waitUntil { viewModel.candles.count == 5 }

        viewModel.onDisappear()
        XCTAssertEqual(fake.cancelCount, 1)
    }

    @MainActor
    func test_initialLoad_emptySeries_becomesEmpty() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 0), for: .h1)
        let viewModel = makeViewModel(service: fake)

        viewModel.onAppear()

        await waitUntil { viewModel.loadingState == .empty }
        XCTAssertTrue(viewModel.candles.isEmpty)
        viewModel.loadOlderCandles()
        XCTAssertEqual(fake.loadOlderCallCount, 0)
        viewModel.onDisappear()
    }

    @MainActor
    func test_retry_afterTimeout_becomesReady() async {
        let fake = ChartProvidingFake()
        let viewModel = makeViewModel(service: fake, loadTimeout: 0.1)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .failed }
        XCTAssertNil(viewModel.snapshot)
        XCTAssertNil(viewModel.selectedCandle)

        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 2), for: .h1)
        viewModel.retry()

        await waitUntil { viewModel.loadingState == .ready }
        XCTAssertEqual(viewModel.candles.count, 2)
        viewModel.onDisappear()
    }

    @MainActor
    func test_timeframeSwitch_loadsNewTimeframe() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 1), for: .h1)
        fake.setInitialFrame(makeSnapshot(timeframe: .d1, count: 5), for: .d1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.selectTimeframe(.d1)

        await waitUntil { viewModel.snapshot?.timeframe == .d1 }
        XCTAssertEqual(viewModel.timeframe, .d1)
        XCTAssertEqual(viewModel.candles.count, 5)
        viewModel.onDisappear()
    }

    @MainActor
    func test_timeframeSwitch_sameTimeframe_isIgnored() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 1), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }
        let subscribesAfterAppear = fake.subscribeCount

        viewModel.selectTimeframe(.h1)

        XCTAssertEqual(fake.subscribeCount, subscribesAfterAppear, "re-selecting the current timeframe must not resubscribe")
        viewModel.onDisappear()
    }

    @MainActor
    func test_timeframeSwitch_failureAndTimeout_revertSelector() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake, timeframe: .h1, loadTimeout: 0.1)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.selectTimeframe(.h4)
        fake.emitFailure()

        await waitUntil { viewModel.timeframe == .h1 && viewModel.loadingState == .ready }
        XCTAssertEqual(viewModel.snapshot?.timeframe, .h1)

        viewModel.selectTimeframe(.h4)

        await waitUntil { viewModel.timeframe == .h1 && viewModel.loadingState == .ready }
        XCTAssertEqual(viewModel.snapshot?.timeframe, .h1)
        XCTAssertEqual(viewModel.candles.count, 3, "selector and chart stay in sync after failure or timeout")
        viewModel.onDisappear()
    }

    @MainActor
    func test_modeToggle_isPureViewState_noResubscribe() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 1), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }
        let subscribes = fake.subscribeCount

        XCTAssertEqual(viewModel.mode, .candle)
        viewModel.toggleMode()
        XCTAssertEqual(viewModel.mode, .line)
        viewModel.toggleMode()
        XCTAssertEqual(viewModel.mode, .candle)
        XCTAssertEqual(fake.subscribeCount, subscribes, "toggling mode must not resubscribe")
        viewModel.onDisappear()
    }

    @MainActor
    func test_liveUpdate_whileCrosshairHeld_isBufferedUntilClear() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.selectCandle(atTime: Date(timeIntervalSince1970: 2000))
        fake.emitUpdate(makeSnapshot(timeframe: .h1, count: 5))
        await drainLiveHop()
        XCTAssertEqual(viewModel.candles.count, 3, "live frame is buffered while inspecting")

        viewModel.selectCandle(atTime: nil)
        XCTAssertEqual(viewModel.candles.count, 5, "clearing the crosshair flushes the buffered frame")
        viewModel.onDisappear()
    }

    @MainActor
    func test_onDisappear_flushesFrameBufferedUnderCrosshair() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.selectCandle(atTime: Date(timeIntervalSince1970: 2000))
        fake.emitUpdate(makeSnapshot(timeframe: .h1, count: 5))
        await drainLiveHop()
        XCTAssertEqual(viewModel.candles.count, 3)

        viewModel.onDisappear()
        XCTAssertEqual(viewModel.candles.count, 5, "leaving flushes the buffered frame instead of dropping it")
    }

    @MainActor
    func test_liveUpdate_fromSupersededWatch_isDropped() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.onDisappear()
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }
        fake.emitUpdate(makeSnapshot(timeframe: .h1, count: 5))
        await waitUntil { viewModel.candles.count == 5 }

        fake.emitStaleUpdate(makeSnapshot(timeframe: .h1, count: 99))
        await drainLiveHop()
        XCTAssertEqual(viewModel.candles.count, 5, "a superseded watch's late frame is dropped")
        viewModel.onDisappear()
    }

    @MainActor
    func test_reconnecting_keepsLastGoodSnapshotAndMarksStale() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        fake.emitReconnecting()

        await waitUntil { viewModel.loadingState == .reconnecting }
        XCTAssertEqual(viewModel.candles.count, 3, "last good candles stay on screen while reconnecting")
        viewModel.onDisappear()
    }

    @MainActor
    func test_terminalFailureAfterSnapshot_becomesFailed() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        fake.emitFailure()

        await waitUntil { viewModel.loadingState == .failed }
        XCTAssertEqual(viewModel.candles.count, 3)
        viewModel.onDisappear()
    }

    @MainActor
    func test_loadOlder_coalescesAndStopsAtHistoryStart() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        fake.deferNextPage(.loaded)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.loadOlderCandles()
        viewModel.loadOlderCandles()
        XCTAssertEqual(fake.loadOlderCallCount, 1, "an in-flight page coalesces the second request")

        fake.completeDeferredPage()
        await drainLiveHop()
        fake.setNextPage(.noMore)
        viewModel.loadOlderCandles()
        XCTAssertEqual(fake.loadOlderCallCount, 2)
        await drainLiveHop()
        fake.setNextPage(.loaded)
        viewModel.loadOlderCandles()
        XCTAssertEqual(fake.loadOlderCallCount, 2, "noMore latches the history start")
        viewModel.onDisappear()
    }

    @MainActor
    func test_loadOlder_completionFromSupersededWatch_isDropped() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        fake.setInitialFrame(makeSnapshot(timeframe: .d1, count: 5), for: .d1)
        fake.deferNextPage(.noMore)
        let viewModel = makeViewModel(service: fake, timeframe: .h1)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.loadOlderCandles()
        await waitUntil { fake.loadOlderCallCount == 1 }

        viewModel.selectTimeframe(.d1)
        await waitUntil { viewModel.snapshot?.timeframe == .d1 }
        fake.completeDeferredPage()
        await drainLiveHop()

        viewModel.loadOlderCandles()
        await waitUntil { fake.loadOlderCallCount == 2 }
        viewModel.onDisappear()
    }

    @MainActor
    func test_loadOlder_historyStartLatch_resetsOnResubscribe() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        fake.setNextPage(.noMore)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.loadOlderCandles()
        XCTAssertEqual(fake.loadOlderCallCount, 1)
        await drainLiveHop()
        viewModel.loadOlderCandles()
        XCTAssertEqual(fake.loadOlderCallCount, 1, "latched within the session")

        viewModel.onDisappear()
        fake.setNextPage(.loaded)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }
        viewModel.loadOlderCandles()
        await waitUntil { fake.loadOlderCallCount == 2 }
        viewModel.onDisappear()
    }

    @MainActor
    func test_selectCandle_exactMatchAndClearsOnNilOrMiss() async {
        let fake = ChartProvidingFake()
        fake.setInitialFrame(makeSnapshot(timeframe: .h1, count: 3), for: .h1)
        let viewModel = makeViewModel(service: fake)
        viewModel.onAppear()
        await waitUntil { viewModel.loadingState == .ready }

        viewModel.selectCandle(atTime: Date(timeIntervalSince1970: 2000))
        XCTAssertEqual(viewModel.selectedCandle?.openedAt.timeIntervalSince1970, 2000)

        viewModel.selectCandle(atTime: Date(timeIntervalSince1970: 9999))
        XCTAssertNil(viewModel.selectedCandle)

        viewModel.selectCandle(atTime: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(viewModel.selectedCandle?.openedAt.timeIntervalSince1970, 1000)
        viewModel.selectCandle(atTime: nil)
        XCTAssertNil(viewModel.selectedCandle)
        viewModel.onDisappear()
    }
}

private extension PerpsChartViewModelTests {
    @MainActor
    func makeViewModel(
        service: ChartProvidingFake,
        timeframe: PerpsChartTimeframe = .h1,
        loadTimeout: TimeInterval = 30
    ) -> PerpsChartViewModel {
        PerpsChartViewModel(marketId: 1, service: service, timeframe: timeframe, loadTimeout: loadTimeout)
    }

    func makeSnapshot(timeframe: PerpsChartTimeframe, count: Int, priceDecimals: Int = 2) -> PerpsChartSnapshot {
        let candles = (0 ..< count).map { index in
            PerpsChartCandle(
                openedAt: Date(timeIntervalSince1970: TimeInterval((index + 1) * 1000)),
                open: 1, high: 2, low: 0.5, close: 1.5, volume: 100
            )
        }
        return PerpsChartSnapshot(
            marketId: 1,
            timeframe: timeframe,
            candles: candles,
            priceDecimals: priceDecimals
        )
    }

    @MainActor
    func drainLiveHop() async {
        await Task { @MainActor in }.value
    }

    func waitUntil(
        timeout: TimeInterval = 2,
        intervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        XCTFail("Timed out waiting for condition")
    }
}

private final class ChartProvidingFake: PerpsChartProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _initialFrames: [PerpsChartTimeframe: PerpsChartSnapshot] = [:]
    private var _subscribeCount = 0
    private var _cancelCount = 0
    private var _onUpdate: (@Sendable (PerpsChartSnapshot) -> Void)?
    private var _onReconnecting: (@Sendable () -> Void)?
    private var _onFailed: (@Sendable () -> Void)?
    private var _staleOnUpdate: (@Sendable (PerpsChartSnapshot) -> Void)?
    private var _loadOlderCallCount = 0
    private var _nextPage: PerpsChartPage = .loaded
    private var _nextDeferredPage: PerpsChartPage?
    private var _deferredPage: PerpsChartPage?
    private var _deferredPageCompletion: (@Sendable (PerpsChartPage) -> Void)?

    var subscribeCount: Int {
        lock.lock(); defer { lock.unlock() }; return _subscribeCount
    }

    var cancelCount: Int {
        lock.lock(); defer { lock.unlock() }; return _cancelCount
    }

    var loadOlderCallCount: Int {
        lock.lock(); defer { lock.unlock() }; return _loadOlderCallCount
    }

    func setInitialFrame(_ snapshot: PerpsChartSnapshot?, for timeframe: PerpsChartTimeframe) {
        lock.lock(); _initialFrames[timeframe] = snapshot; lock.unlock()
    }

    func setNextPage(_ page: PerpsChartPage) {
        lock.lock(); _nextPage = page; lock.unlock()
    }

    func deferNextPage(_ page: PerpsChartPage) {
        lock.lock(); _nextDeferredPage = page; lock.unlock()
    }

    func completeDeferredPage() {
        lock.lock()
        let page = _deferredPage
        let completion = _deferredPageCompletion
        _deferredPage = nil
        _deferredPageCompletion = nil
        lock.unlock()
        if let page { completion?(page) }
    }

    func watchChart(
        marketId: Int64,
        timeframe: PerpsChartTimeframe,
        onUpdate: @escaping @Sendable (PerpsChartSnapshot) -> Void,
        onReconnecting: @escaping @Sendable () -> Void,
        onFailed: @escaping @Sendable () -> Void
    ) -> PerpsChartWatch {
        lock.lock()
        _subscribeCount += 1
        _staleOnUpdate = _onUpdate
        _onUpdate = onUpdate
        _onReconnecting = onReconnecting
        _onFailed = onFailed
        let initial = _initialFrames[timeframe]
        lock.unlock()
        if let initial { onUpdate(initial) }
        return PerpsChartWatch(
            onCancel: { [weak self] in
                guard let self else { return }
                self.lock.lock(); self._cancelCount += 1; self.lock.unlock()
            },
            onLoadOlder: { [weak self] _, onLoaded in
                guard let self else { return }
                self.lock.lock()
                self._loadOlderCallCount += 1
                if let deferredPage = self._nextDeferredPage {
                    self._nextDeferredPage = nil
                    self._deferredPage = deferredPage
                    self._deferredPageCompletion = onLoaded
                    self.lock.unlock()
                    return
                }
                let page = self._nextPage
                self.lock.unlock()
                onLoaded(page)
            }
        )
    }

    func emitUpdate(_ snapshot: PerpsChartSnapshot) {
        lock.lock(); let cb = _onUpdate; lock.unlock()
        cb?(snapshot)
    }

    func emitStaleUpdate(_ snapshot: PerpsChartSnapshot) {
        lock.lock(); let cb = _staleOnUpdate; lock.unlock()
        cb?(snapshot)
    }

    func emitReconnecting() {
        lock.lock(); let cb = _onReconnecting; lock.unlock()
        cb?()
    }

    func emitFailure() {
        lock.lock(); let cb = _onFailed; lock.unlock()
        cb?()
    }
}
