import Foundation

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
