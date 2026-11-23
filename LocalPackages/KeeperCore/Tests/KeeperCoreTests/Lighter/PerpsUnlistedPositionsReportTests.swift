@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsUnlistedPositionsReportTests: XCTestCase {
    func testAPositionOnAnUnlistedMarketIsReportedOncePerMarket() async {
        let reports = Reports()
        let report = PerpsUnlistedPositionsReport(signedSymbols: { [2: "SOL"] }, report: { reports.append($0) })

        await report.check([position(2, "SOL"), position(28, "MKR")])
        await report.check([position(28, "MKR")])

        XCTAssertEqual(reports.values, ["perps position on market 28 MKR, which the signed perps config does not list"])
    }

    func testNothingIsReportedWithoutAVerifiedConfig() async {
        let reports = Reports()
        let report = PerpsUnlistedPositionsReport(signedSymbols: { nil }, report: { reports.append($0) })

        await report.check([position(28, "MKR")])

        XCTAssertTrue(reports.values.isEmpty)
    }

    private func position(_ marketId: Int64, _ symbol: String) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:\(marketId)",
            marketId: marketId,
            symbol: symbol,
            side: .long,
            baseSize: 1,
            notionalUsd: 10,
            marginUsd: 1,
            equityUsd: 1,
            leverage: 10,
            roiPercent: nil,
            entryPrice: 1,
            liquidationPrice: 0.9,
            unrealizedPnlUsd: 0,
            realizedPnlUsd: 0,
            fundingPaidUsd: nil
        )
    }
}

private final class Reports: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = [String]()

    var values: [String] {
        lock.withLock { stored }
    }

    func append(_ value: String) {
        lock.withLock { stored.append(value) }
    }
}
