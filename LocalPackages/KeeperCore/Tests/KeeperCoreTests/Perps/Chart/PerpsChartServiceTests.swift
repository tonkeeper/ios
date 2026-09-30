@testable import KeeperCore
import TKKandelabrAPI
import XCTest

final class PerpsChartServiceTests: XCTestCase {
    func test_watchChart_loadsSnapshotUsingResolvedMarketMetadata() async {
        let kandelabr = KandelabrFake(snapshot: makeBatch(ticker: "BTC/USD", resolution: "1m", close: "101"))
        let hermes = HermesFake()
        let markets = MarketsReadingFake(markets: [
            .fake(marketId: 1, symbol: "BTCUSDT", ticker: "BTC/USD"),
        ])
        let service = makeService(kandelabr: kandelabr, hermes: hermes, markets: markets)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 1,
            timeframe: .m1,
            onUpdate: { received.set($0) },
            onReconnecting: {}
        )
        await waitUntil { received.value()?.priceDecimals == 5 }

        XCTAssertEqual(received.value()?.marketId, 1)
        XCTAssertEqual(received.value()?.timeframe, .m1)
        XCTAssertEqual(received.value()?.candles.first?.close, 101)
        XCTAssertEqual(kandelabr.ticker, "BTC/USD")
        XCTAssertEqual(kandelabr.resolution, "1m")
        XCTAssertEqual(kandelabr.limit, 500)
        await waitUntil { hermes.feedId == "BTC/USD/1m" }
        watch.cancel()
        await waitUntil { hermes.cancelCount == 1 }
    }

    func test_watchChart_transientHistoryFailureCanRecoverFromHermes() async {
        let kandelabr = KandelabrFake(
            snapshots: [makeBatch(close: "100")],
            errors: [.badStatus(500)]
        )
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let failed = Locked(false)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {},
            onFailed: { failed.set(true) }
        )
        await waitUntil { hermes.isWatching && kandelabr.snapshotCalls == 1 }

        await hermes.emit(makeBatch(close: "120"))

        await waitUntil { received.value()?.candles.first?.close == 120 }
        XCTAssertFalse(failed.value())
        XCTAssertEqual(hermes.cancelCount, 0)
        watch.cancel()
    }

    func test_watchChart_buffersLiveUpdateUntilInitialSnapshotAndKeepsLiveValue() async {
        let gate = AsyncGate()
        let kandelabr = KandelabrFake(
            snapshots: [makeBatch(candles: [makeWireCandle(close: "100"), makeWireCandle(close: "101")])],
            gates: [gate]
        )
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let updateCount = Locked(0)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { snapshot in
                received.set(snapshot)
                updateCount.update { $0 += 1 }
            },
            onReconnecting: {}
        )
        await waitUntil { hermes.isWatching && kandelabr.snapshotCalls == 1 }

        await hermes.emit(makeBatch(startTs: 1_700_003_600_000, close: "110"))
        await hermes.emit(makeBatch(startTs: 1_700_003_600_000, close: "120"))
        XCTAssertNil(received.value())

        await gate.open()
        await waitUntil { received.value()?.candles.map(\.close) == [100, 120] }
        XCTAssertEqual(updateCount.value(), 1)
        watch.cancel()
    }

    func test_watchChart_refreshesAfterResubscribeWithoutOverwritingNewerLiveValue() async {
        let refreshGate = AsyncGate()
        let kandelabr = KandelabrFake(
            snapshots: [makeBatch(close: "100"), makeBatch(close: "120")],
            gates: [nil, refreshGate]
        )
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {}
        )
        await waitUntil { received.value()?.candles.first?.close == 100 }

        await hermes.emitSubscribed()
        await waitUntil { kandelabr.snapshotCalls == 2 }
        await hermes.emit(makeBatch(close: "130"))
        await refreshGate.open()

        await waitUntil { received.value()?.candles.first?.close == 130 }
        XCTAssertEqual(kandelabr.snapshotCalls, 2)
        watch.cancel()
    }

    func test_watchChart_refreshesWhenResubscribeCompletesDuringInitialHistoryLoad() async {
        let initialGate = AsyncGate()
        let kandelabr = KandelabrFake(
            snapshots: [makeBatch(close: "100"), makeBatch(close: "120")],
            gates: [initialGate, nil]
        )
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {}
        )
        await waitUntil { hermes.isWatching && kandelabr.snapshotCalls == 1 }

        await hermes.emitSubscribed()
        await hermes.emitSubscribed()
        await initialGate.open()

        await waitUntil { received.value()?.candles.first?.close == 120 }
        XCTAssertEqual(kandelabr.snapshotCalls, 2)
        watch.cancel()
    }

    func test_watchChart_ignoresSupersededRefreshCompletion() async {
        let firstRefreshGate = AsyncGate()
        let currentRefreshGate = AsyncGate()
        let kandelabr = KandelabrFake(
            snapshots: [makeBatch(close: "100"), makeBatch(close: "120"), makeBatch(close: "140")],
            gates: [nil, firstRefreshGate, currentRefreshGate]
        )
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {}
        )
        await waitUntil { received.value()?.candles.first?.close == 100 }

        await hermes.emitSubscribed()
        await waitUntil { kandelabr.snapshotCalls == 2 }
        await hermes.emitSubscribed()
        await waitUntil { kandelabr.snapshotCalls == 3 }

        await firstRefreshGate.open()
        await waitUntil { kandelabr.completedSnapshotCalls == 2 }
        XCTAssertEqual(received.value()?.candles.first?.close, 100)

        await currentRefreshGate.open()
        await waitUntil { received.value()?.candles.first?.close == 140 }
        watch.cancel()
    }

    func test_watchChart_appliesRapidHermesUpdatesInDeliveryOrder() async {
        let kandelabr = KandelabrFake(snapshot: makeBatch(close: "100"))
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {}
        )
        await waitUntil { hermes.isWatching }

        await hermes.emit(makeBatch(close: "110"))
        await hermes.emit(makeBatch(close: "120"))

        XCTAssertEqual(received.value()?.candles.first?.close, 120)
        watch.cancel()
    }

    func test_watchChart_forwardsReconnectAndPaging() async {
        let older = makeBatch(
            startTs: 1_699_996_400_000,
            candles: [makeWireCandle(close: "90")]
        )
        let kandelabr = KandelabrFake(snapshot: makeBatch(close: "100"), older: older)
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let reconnected = Locked(false)
        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: { reconnected.set(true) }
        )
        await waitUntil { received.value() != nil }
        await waitUntil { hermes.isWatching }

        await hermes.emitReconnecting()
        await waitUntil { reconnected.value() }

        let page = Locked<PerpsChartPage?>(nil)
        watch.loadOlder(count: 150) { page.set($0) }
        await waitUntil { page.value() != nil }
        XCTAssertEqual(page.value(), .loaded)
        XCTAssertEqual(kandelabr.endTs, 1_700_000_000_000)
        XCTAssertEqual(kandelabr.limit, 150)
        XCTAssertEqual(received.value()?.candles.map(\.close), [90, 100])
        watch.cancel()
    }

    func test_watchChart_paginatesFromWireTimelineWhenInitialCandlesAreEmpty() async {
        let startTs: Int64 = 1_700_000_000_000
        let initial = makeBatch(
            startTs: startTs,
            candles: [
                makeWireCandle(close: "0", empty: true),
                makeWireCandle(close: "0", empty: true),
            ]
        )
        let older = makeBatch(
            startTs: startTs - 3_600_000,
            candles: [makeWireCandle(close: "90")]
        )
        let kandelabr = KandelabrFake(snapshot: initial, older: older)
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {}
        )
        await waitUntil { received.value() != nil }
        XCTAssertEqual(received.value()?.candles, [])

        let page = Locked<PerpsChartPage?>(nil)
        watch.loadOlder(count: 150) { page.set($0) }

        await waitUntil { page.value() != nil }
        XCTAssertEqual(page.value(), .loaded)
        XCTAssertEqual(kandelabr.endTs, startTs)
        XCTAssertEqual(received.value()?.candles.map(\.close), [90])
        watch.cancel()
    }

    func test_watchChart_keepsHistoryChartWhenHermesRejectsFeed() async {
        let older = makeBatch(
            startTs: 1_699_996_400_000,
            candles: [makeWireCandle(close: "90")]
        )
        let kandelabr = KandelabrFake(snapshot: makeBatch(close: "100"), older: older)
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let failed = Locked(false)
        let updateCount = Locked(0)
        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { snapshot in
                received.set(snapshot)
                updateCount.update { $0 += 1 }
            },
            onReconnecting: {},
            onFailed: { failed.set(true) }
        )
        await waitUntil { received.value() != nil && hermes.isWatching }

        await hermes.emitReconnecting()
        await hermes.emitRejected()
        await waitUntil { hermes.cancelCount == 1 && updateCount.value() == 2 }

        let page = Locked<PerpsChartPage?>(nil)
        watch.loadOlder(count: 150) { page.set($0) }
        await waitUntil { page.value() == .loaded }
        XCTAssertEqual(received.value()?.candles.map(\.close), [90, 100])
        XCTAssertFalse(failed.value())
        watch.cancel()
    }

    func test_watchChart_rejectDuringHistoryLoadStillDeliversHistory() async {
        let gate = AsyncGate()
        let kandelabr = KandelabrFake(snapshots: [makeBatch(close: "100")], gates: [gate])
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let failed = Locked(false)
        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {},
            onFailed: { failed.set(true) }
        )
        await waitUntil { hermes.isWatching && kandelabr.snapshotCalls == 1 }

        await hermes.emitRejected()
        await gate.open()

        await waitUntil { received.value()?.candles.first?.close == 100 }
        XCTAssertFalse(failed.value())
        watch.cancel()
    }

    func test_watchChart_rejectWithoutAnyHistoryFails() async {
        let gate = AsyncGate()
        let kandelabr = KandelabrFake(
            snapshots: [makeBatch(close: "100")],
            gates: [gate],
            errors: [.badStatus(500)]
        )
        let hermes = HermesFake()
        let service = makeService(kandelabr: kandelabr, hermes: hermes)

        let failed = Locked(false)
        let received = Locked<PerpsChartSnapshot?>(nil)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {},
            onFailed: { failed.set(true) }
        )
        await waitUntil { hermes.isWatching && kandelabr.snapshotCalls == 1 }

        await hermes.emitRejected()
        await gate.open()

        await waitUntil { failed.value() }
        XCTAssertNil(received.value())
        watch.cancel()
    }

    func test_watchChart_missingMarketDoesNotOpenFeeds() async {
        let kandelabr = KandelabrFake(snapshot: makeBatch())
        let hermes = HermesFake()
        let markets = MarketsReadingFake(markets: [])
        let service = makeService(
            kandelabr: kandelabr,
            hermes: hermes,
            markets: markets
        )

        let received = Locked<PerpsChartSnapshot?>(nil)
        let failed = Locked(false)
        let watch = service.watchChart(
            marketId: 7,
            timeframe: .h1,
            onUpdate: { received.set($0) },
            onReconnecting: {},
            onFailed: { failed.set(true) }
        )
        await waitUntil { failed.value() }
        XCTAssertEqual(markets.detailsCalls, 1)
        XCTAssertNil(received.value())
        XCTAssertNil(kandelabr.ticker)
        XCTAssertFalse(hermes.isWatching)
        watch.cancel()
    }
}

private extension PerpsChartServiceTests {
    func makeService(
        kandelabr: KandelabrFake,
        hermes: HermesFake,
        markets: MarketsReadingFake = MarketsReadingFake(markets: [
            .fake(marketId: 7, symbol: "ETH", ticker: "ETH/USD"),
        ])
    ) -> PerpsChartService {
        PerpsChartService(
            kandelabr: kandelabr,
            hermes: hermes,
            marketsRepository: markets
        )
    }

    func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }
}

private func makeBatch(
    ticker: String = "ETH/USD",
    resolution: String = "1h",
    startTs: Int64 = 1_700_000_000_000,
    candles: [TKKandelabrAPI.Components.Schemas.Candle]? = nil,
    close: String = "100"
) -> TKKandelabrAPI.Components.Schemas.GetCandlesResponse {
    .init(
        ticker: ticker,
        resolution: resolution,
        start_ts: startTs,
        candles: candles ?? [makeWireCandle(close: close)]
    )
}

private func makeWireCandle(
    close: String,
    empty: Bool? = nil
) -> TKKandelabrAPI.Components.Schemas.Candle {
    .init(o: close, h: close, l: close, c: close, v: "1", empty: empty)
}

private final class Locked<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) {
        self._value = value
    }

    func set(_ newValue: T) {
        lock.lock(); _value = newValue; lock.unlock()
    }

    func value() -> T {
        lock.lock(); defer { lock.unlock() }; return _value
    }

    func update(_ body: (inout T) -> Void) {
        lock.lock(); defer { lock.unlock() }
        body(&_value)
    }
}

private final class KandelabrFake: KandelabrAPI, @unchecked Sendable {
    private let lock = NSLock()
    private let snapshots: [TKKandelabrAPI.Components.Schemas.GetCandlesResponse]
    private let gates: [AsyncGate?]
    private let errors: [KandelabrAPIError?]
    private let older: TKKandelabrAPI.Components.Schemas.GetCandlesResponse?
    private var _ticker: String?
    private var _resolution: String?
    private var _limit: Int32?
    private var _endTs: Int64?
    private var _snapshotCalls = 0
    private var _completedSnapshotCalls = 0

    init(
        snapshot: TKKandelabrAPI.Components.Schemas.GetCandlesResponse,
        older: TKKandelabrAPI.Components.Schemas.GetCandlesResponse? = nil
    ) {
        snapshots = [snapshot]
        gates = []
        errors = []
        self.older = older
    }

    init(
        snapshots: [TKKandelabrAPI.Components.Schemas.GetCandlesResponse],
        gates: [AsyncGate?] = [],
        errors: [KandelabrAPIError?] = []
    ) {
        self.snapshots = snapshots
        self.gates = gates
        self.errors = errors
        older = nil
    }

    var ticker: String? {
        lock.withLock { _ticker }
    }

    var resolution: String? {
        lock.withLock { _resolution }
    }

    var limit: Int32? {
        lock.withLock { _limit }
    }

    var endTs: Int64? {
        lock.withLock { _endTs }
    }

    var snapshotCalls: Int {
        lock.withLock { _snapshotCalls }
    }

    var completedSnapshotCalls: Int {
        lock.withLock { _completedSnapshotCalls }
    }

    func candles(
        ticker: String,
        resolution: String,
        limit: Int32?,
        startTs _: Int64?,
        endTs: Int64?
    ) async throws(KandelabrAPIError) -> TKKandelabrAPI.Components.Schemas.GetCandlesResponse {
        remember(ticker: ticker, resolution: resolution, limit: limit, endTs: endTs)
        if endTs != nil, let older {
            return older
        }
        let (snapshot, gate, error) = lock.withLock {
            let index = _snapshotCalls
            _snapshotCalls += 1
            return (
                snapshots[min(index, snapshots.count - 1)],
                index < gates.count ? gates[index] : nil,
                index < errors.count ? errors[index] : nil
            )
        }
        await gate?.wait()
        lock.withLock { _completedSnapshotCalls += 1 }
        if let error { throw error }
        return snapshot
    }

    private func remember(ticker: String, resolution: String, limit: Int32?, endTs: Int64?) {
        lock.lock()
        _ticker = ticker
        _resolution = resolution
        _limit = limit
        _endTs = endTs
        lock.unlock()
    }
}

private final class HermesFake: HermesCandleStreaming, @unchecked Sendable {
    private let lock = NSLock()
    private var _feedId: String?
    private var _onUpdate: (@Sendable (TKKandelabrAPI.Components.Schemas.GetCandlesResponse) async -> Void)?
    private var _onSubscribed: (@Sendable () async -> Void)?
    private var _onReconnecting: (@Sendable () async -> Void)?
    private var _onRejected: (@Sendable () async -> Void)?
    private var _cancelCount = 0

    var feedId: String? {
        lock.withLock { _feedId }
    }

    var isWatching: Bool {
        lock.withLock { _onUpdate != nil }
    }

    var cancelCount: Int {
        lock.withLock { _cancelCount }
    }

    func emit(_ batch: TKKandelabrAPI.Components.Schemas.GetCandlesResponse) async {
        let cb = lock.withLock { _onUpdate }
        await cb?(batch)
    }

    func emitSubscribed() async {
        let cb = lock.withLock { _onSubscribed }
        await cb?()
    }

    func emitReconnecting() async {
        let cb = lock.withLock { _onReconnecting }
        await cb?()
    }

    func emitRejected() async {
        let cb = lock.withLock { _onRejected }
        await cb?()
    }

    func watch(
        feedId: String,
        onUpdate: @escaping @Sendable (TKKandelabrAPI.Components.Schemas.GetCandlesResponse) async -> Void,
        onSubscribed: @escaping @Sendable () async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesCandleWatch {
        lock.lock()
        _feedId = feedId
        _onUpdate = onUpdate
        _onSubscribed = onSubscribed
        _onReconnecting = onReconnecting
        _onRejected = onRejected
        lock.unlock()
        return HermesCandleWatch(
            onCancel: { [weak self] in
                guard let self else { return }
                self.lock.lock(); self._cancelCount += 1; self.lock.unlock()
            }
        )
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private extension PerpsMarketMetadata {
    static func fake(
        marketId: Int64,
        symbol: String,
        ticker: String,
        priceDecimals: Int = 5
    ) -> PerpsMarketMetadata {
        PerpsMarketMetadata(
            marketId: marketId,
            symbol: symbol,
            ticker: ticker,
            status: "active",
            markPrice: nil,
            lastTradePrice: nil,
            priceChangePercent: 0,
            volume24h: 0,
            openInterest: 0,
            maxLeverage: 20,
            fundingRatePercent: nil,
            priceDecimals: priceDecimals,
            sizeDecimals: 2,
            minBaseSize: 0.001
        )
    }
}

private final class MarketsReadingFake: PerpsMarketsReading, @unchecked Sendable {
    private let lock = NSLock()
    private let source: [Int64: PerpsMarketMetadata]
    private var _detailsCalls = 0

    init(markets: [PerpsMarketMetadata]) {
        source = Dictionary(uniqueKeysWithValues: markets.map { ($0.marketId, $0) })
    }

    var detailsCalls: Int {
        lock.withLock { _detailsCalls }
    }

    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?) async throws -> PerpsMarketsPage {
        PerpsMarketsPage(items: [], nextCursor: nil)
    }

    func marketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        lock.withLock { _detailsCalls += 1 }
        guard let market = source[marketId] else {
            throw PerpsMarketsRepositoryError.marketNotFound
        }
        return PerpsMarketDetails(metadata: market, name: "", iconURL: nil, about: nil)
    }
}

private extension NSLock {
    func withLock<T>(_ closure: () -> T) -> T {
        lock()
        defer { unlock() }
        return closure()
    }
}
