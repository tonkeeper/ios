import Foundation
import PerpsModels
import TKLogging

actor PerpsUnlistedPositionsReport {
    private let signedSymbols: @Sendable () async -> [Int64: String]?
    private let report: @Sendable (String) -> Void
    private var reportedMarkets = Set<Int64>()

    init(
        signedSymbols: @escaping @Sendable () async -> [Int64: String]?,
        report: @escaping @Sendable (String) -> Void = { Log.perps.e($0) }
    ) {
        self.signedSymbols = signedSymbols
        self.report = report
    }

    func check(_ positions: [PerpsPositionSummary]) async {
        guard !positions.isEmpty, let signed = await signedSymbols() else { return }
        for position in positions where signed[position.marketId] == nil && !reportedMarkets.contains(position.marketId) {
            reportedMarkets.insert(position.marketId)
            report("perps position on market \(position.marketId) \(position.symbol), which the signed perps config does not list")
        }
    }
}
