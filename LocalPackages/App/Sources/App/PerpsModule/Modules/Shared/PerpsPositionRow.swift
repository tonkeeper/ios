import Foundation
import KeeperCore
import TKLocalize

struct PerpsPositionRowItem: Identifiable, Equatable {
    let id: Int64
    let symbol: String
    let iconURL: URL?
    let leverageText: String?
    let sideText: String
    let isLong: Bool
    let valueText: String
    let pnlText: String
    let isPnlPositive: Bool
}

struct PerpsPositionsTotal: Equatable {
    let amountText: String
    let pnlText: String
    let pnlPercentText: String?
    let isPnlPositive: Bool
}

enum PerpsPositionRowMapping {
    static func rows(
        from positions: [PerpsPositionSummary],
        iconURL: (Int64) -> URL?
    ) -> [PerpsPositionRowItem] {
        positions
            .sorted { $0.marketId < $1.marketId }
            .map { item(from: $0, iconURL: iconURL($0.marketId)) }
    }

    private static func item(from summary: PerpsPositionSummary, iconURL: URL?) -> PerpsPositionRowItem {
        PerpsPositionRowItem(
            id: summary.marketId,
            symbol: summary.symbol,
            iconURL: iconURL,
            leverageText: summary.leverage.map { PerpsFormatting.leverage($0).uppercased() },
            sideText: (summary.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isLong: summary.side == .long,
            valueText: PerpsFormatting.usd(summary.equityUsd),
            pnlText: PerpsFormatting.signedUsd(summary.unrealizedPnlUsd),
            isPnlPositive: summary.unrealizedPnlUsd >= 0
        )
    }

    static func total(positions: [PerpsPositionSummary]) -> PerpsPositionsTotal? {
        guard !positions.isEmpty else { return nil }
        let amount = positions.reduce(0) { $0 + $1.equityUsd }
        let pnl = positions.reduce(0) { $0 + $1.unrealizedPnlUsd }
        let margin = positions.reduce(0) { $0 + $1.marginUsd }
        let everyPositionHasMargin = positions.allSatisfy { $0.marginUsd > 0 }
        return PerpsPositionsTotal(
            amountText: PerpsFormatting.usd(amount),
            pnlText: PerpsFormatting.signedUsd(pnl),
            pnlPercentText: everyPositionHasMargin ? PerpsFormatting.signedPercent(pnl / margin * 100) : nil,
            isPnlPositive: pnl >= 0
        )
    }
}
