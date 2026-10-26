import Foundation
import PerpsModels

@MainActor
final class PerpsChartViewModel: ObservableObject, PerpsChartViewModeling {
    typealias LoadingState = PerpsChartLoadingState
    typealias SelectedChange = PerpsChartSelectedChange

    @Published private(set) var loadingState: LoadingState = .loading
    @Published private(set) var snapshot: PerpsChartSnapshot?
    @Published private(set) var timeframe: PerpsChartTimeframe
    @Published private(set) var mode: PerpsChartMode = .candle
    @Published private(set) var selectedCandle: PerpsChartCandle?
    private var selectedBaseline: PerpsChartCandle?

    let marketId: Int64
    private let service: PerpsChartProviding
    private let format: PerpsFormatting

    private var indexByTime: [TimeInterval: Int] = [:]

    private var watchGeneration = 0
    private var chartWatch: PerpsChartWatch?
    private var loadTimeoutTask: Task<Void, Never>?
    private var awaitingFirstFrame = false
    private var pendingLiveSnapshot: PerpsChartSnapshot?
    private var isPaginating = false
    private var reachedHistoryStart = false
    private let historyPageSize: Int64 = 200
    private let loadTimeout: TimeInterval

    init(
        marketId: Int64,
        service: PerpsChartProviding,
        format: PerpsFormatting,
        timeframe: PerpsChartTimeframe = .m5,
        loadTimeout: TimeInterval = 15
    ) {
        self.marketId = marketId
        self.service = service
        self.format = format
        self.timeframe = timeframe
        self.loadTimeout = loadTimeout
    }

    var candles: [PerpsChartCandle] {
        snapshot?.candles ?? []
    }

    var priceDecimals: Int {
        snapshot?.priceDecimals ?? 2
    }

    func onAppear() {
        startWatching()
    }

    func onDisappear() {
        stopWatching()
        clearSelection()
    }

    func retry() {
        startWatching()
    }

    func selectTimeframe(_ newValue: PerpsChartTimeframe) {
        guard newValue != timeframe else { return }
        clearSelection()
        timeframe = newValue
        startWatching()
    }

    func selectMode(_ newValue: PerpsChartMode) {
        mode = newValue
    }

    func loadOlderCandles() {
        guard !isPaginating, !reachedHistoryStart,
              !(snapshot?.candles.isEmpty ?? true), let chartWatch
        else { return }
        isPaginating = true
        let generation = watchGeneration
        chartWatch.loadOlder(count: historyPageSize) { [weak self] page in
            Task { @MainActor in self?.finishPagination(page, generation: generation) }
        }
    }

    func selectCandle(atTime time: Date?, baselineTime: Date? = nil) {
        guard let time,
              let index = indexByTime[time.timeIntervalSince1970],
              candles.indices.contains(index)
        else {
            clearSelection()
            return
        }
        selectedBaseline = baselineTime
            .flatMap { indexByTime[$0.timeIntervalSince1970] }
            .map { candles[$0] } ?? candles.first
        let candle = candles[index]
        guard candle != selectedCandle else { return }
        selectedCandle = candle
    }

    /// A candle measures its own close against its open; the line measures the selected
    /// close against the close of the leftmost visible candle.
    var selectedChange: SelectedChange? {
        guard let candle = selectedCandle else { return nil }
        let base = switch mode {
        case .candle: candle.open
        case .line: (selectedBaseline ?? candle).close
        }
        let amount = candle.close - base
        return SelectedChange(
            percent: base > 0 ? amount / base * 100 : 0,
            amount: amount,
            isPositive: amount >= 0
        )
    }

    var crosshairReadout: PerpsChartCrosshairReadout? {
        guard let candle = selectedCandle else { return nil }
        let change = selectedChange
        return PerpsChartCrosshairReadout(
            dateTime: format.candleDateTime(candle.openedAt),
            openText: format.usd(candle.open),
            closeText: format.usd(candle.close),
            percentText: format.signedPercent(change?.percent ?? 0),
            amountText: format.signedUsd(change?.amount ?? 0),
            volumeText: candle.volume.map { format.usd($0) } ?? "—",
            highText: format.usd(candle.high),
            lowText: format.usd(candle.low),
            isPositive: change?.isPositive ?? true
        )
    }
}

private extension PerpsChartViewModel {
    func startWatching() {
        stopWatching()
        reachedHistoryStart = false
        watchGeneration += 1
        let generation = watchGeneration
        awaitingFirstFrame = true
        if snapshot?.timeframe != timeframe {
            loadingState = .loading
        }
        chartWatch = service.watchChart(
            marketId: marketId,
            timeframe: timeframe,
            onUpdate: { [weak self] snapshot in
                Task { @MainActor in self?.applyLive(snapshot, generation: generation) }
            },
            onReconnecting: { [weak self] in
                Task { @MainActor in self?.applyReconnecting(generation: generation) }
            },
            onFailed: { [weak self] in
                Task { @MainActor in self?.applyFailure(generation: generation) }
            }
        )
        loadTimeoutTask = Task { [weak self, loadTimeout] in
            try? await Task.sleep(nanoseconds: UInt64(loadTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.handleLoadTimeout(generation: generation)
        }
    }

    func stopWatching() {
        chartWatch?.cancel()
        chartWatch = nil
        loadTimeoutTask?.cancel()
        loadTimeoutTask = nil
        awaitingFirstFrame = false
        isPaginating = false
        watchGeneration += 1
    }

    func applyLive(_ result: PerpsChartSnapshot, generation: Int) {
        guard generation == watchGeneration else { return }
        awaitingFirstFrame = false
        loadTimeoutTask?.cancel()
        loadTimeoutTask = nil
        applySnapshot(result)
    }

    func applySnapshot(_ result: PerpsChartSnapshot) {
        guard result.timeframe == timeframe else { return }
        guard selectedCandle == nil else {
            pendingLiveSnapshot = result
            return
        }
        let timelineChanged = snapshot?.candles.hasSameTimeline(as: result.candles) != true
        snapshot = result
        if timelineChanged {
            indexByTime = Dictionary(
                result.candles.enumerated().map { ($0.element.openedAt.timeIntervalSince1970, $0.offset) },
                uniquingKeysWith: { _, latest in latest }
            )
        }
        loadingState = result.candles.isEmpty ? .empty : .ready
    }

    func handleLoadTimeout(generation: Int) {
        guard generation == watchGeneration, awaitingFirstFrame else { return }
        awaitingFirstFrame = false
        if restoreLoadedTimeframe() { return }
        if snapshot == nil {
            loadingState = .failed
        } else {
            loadingState = .reconnecting
        }
    }

    func applyReconnecting(generation: Int) {
        guard generation == watchGeneration, loadingState == .ready else { return }
        loadingState = .reconnecting
    }

    func applyFailure(generation: Int) {
        guard generation == watchGeneration else { return }
        let failedDuringInitialLoad = awaitingFirstFrame
        awaitingFirstFrame = false
        loadTimeoutTask?.cancel()
        loadTimeoutTask = nil
        if failedDuringInitialLoad, restoreLoadedTimeframe() { return }
        loadingState = .failed
    }

    func restoreLoadedTimeframe() -> Bool {
        guard let snapshot, snapshot.timeframe != timeframe else { return false }
        timeframe = snapshot.timeframe
        loadingState = .ready
        startWatching()
        return true
    }

    func finishPagination(_ page: PerpsChartPage, generation: Int) {
        guard generation == watchGeneration else { return }
        isPaginating = false
        if page == .noMore { reachedHistoryStart = true }
    }

    func clearSelection() {
        let hadSelection = selectedCandle != nil
        selectedCandle = nil
        selectedBaseline = nil
        if hadSelection, let pending = pendingLiveSnapshot {
            pendingLiveSnapshot = nil
            applySnapshot(pending)
        }
    }
}

private extension [PerpsChartCandle] {
    func hasSameTimeline(as other: Self) -> Bool {
        count == other.count && zip(self, other).allSatisfy { $0.openedAt == $1.openedAt }
    }
}
