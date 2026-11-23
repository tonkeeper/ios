import Foundation
import PerpsModels

final class PerpsChartService: PerpsChartProviding, Sendable {
    static let defaultPriceDecimals = 2

    private let kandelabr: KandelabrAPI
    private let hermes: HermesCandleStreaming
    private let marketsRepository: PerpsMarketsReading
    private let snapshotBars: Int32
    private let now: @Sendable () -> Date

    init(
        kandelabr: KandelabrAPI,
        hermes: HermesCandleStreaming,
        marketsRepository: PerpsMarketsReading,
        snapshotBars: Int32 = 500,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.kandelabr = kandelabr
        self.hermes = hermes
        self.marketsRepository = marketsRepository
        self.snapshotBars = snapshotBars
        self.now = now
    }

    func watchChart(
        marketId: Int64,
        timeframe: PerpsChartTimeframe,
        onUpdate: @escaping @Sendable (PerpsChartSnapshot) -> Void,
        onReconnecting: @escaping @Sendable () -> Void,
        onFailed: @escaping @Sendable () -> Void = {}
    ) -> PerpsChartWatch {
        let session = PerpsChartSession(
            marketId: marketId,
            timeframe: timeframe,
            kandelabr: kandelabr,
            hermes: hermes,
            marketsRepository: marketsRepository,
            snapshotBars: snapshotBars,
            now: now,
            onUpdate: onUpdate,
            onReconnecting: onReconnecting,
            onFailed: onFailed
        )
        Task { await session.start() }
        return PerpsChartWatch(
            onCancel: { Task { await session.cancel() } },
            onLoadOlder: { count, done in Task { await session.loadOlder(count: count, onLoaded: done) } }
        )
    }
}
