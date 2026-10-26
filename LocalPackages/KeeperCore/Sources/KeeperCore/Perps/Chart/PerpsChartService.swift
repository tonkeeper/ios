import Foundation
import PerpsModels
import TKKandelabrAPI

final class PerpsChartService: PerpsChartProviding, Sendable {
    static let defaultPriceDecimals = 2

    private let kandelabr: KandelabrAPI
    private let hermes: HermesCandleStreaming
    private let marketsRepository: PerpsMarketsReading
    private let snapshotBars: Int32

    init(
        kandelabr: KandelabrAPI,
        hermes: HermesCandleStreaming,
        marketsRepository: PerpsMarketsReading,
        snapshotBars: Int32 = 500
    ) {
        self.kandelabr = kandelabr
        self.hermes = hermes
        self.marketsRepository = marketsRepository
        self.snapshotBars = snapshotBars
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
