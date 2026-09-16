import Foundation
import TKKandelabrAPI

public enum PerpsChartPage: Sendable, Equatable {
    case loaded
    case noMore
    case busy
    case failed
}

public struct PerpsChartWatch {
    private let onCancel: @Sendable () -> Void
    private let onLoadOlder: @Sendable (Int64, @escaping @Sendable (PerpsChartPage) -> Void) -> Void

    public init(
        onCancel: @escaping @Sendable () -> Void,
        onLoadOlder: @escaping @Sendable (Int64, @escaping @Sendable (PerpsChartPage) -> Void) -> Void = { _, done in done(.noMore) }
    ) {
        self.onCancel = onCancel
        self.onLoadOlder = onLoadOlder
    }

    public func cancel() {
        onCancel()
    }

    public func loadOlder(count: Int64, onLoaded: @escaping @Sendable (PerpsChartPage) -> Void) {
        onLoadOlder(count, onLoaded)
    }
}

public protocol PerpsChartProviding: AnyObject, Sendable {
    func watchChart(
        marketId: Int64,
        timeframe: PerpsChartTimeframe,
        onUpdate: @escaping @Sendable (PerpsChartSnapshot) -> Void,
        onReconnecting: @escaping @Sendable () -> Void,
        onFailed: @escaping @Sendable () -> Void
    ) -> PerpsChartWatch
}

final class PerpsChartService: PerpsChartProviding, @unchecked Sendable {
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
