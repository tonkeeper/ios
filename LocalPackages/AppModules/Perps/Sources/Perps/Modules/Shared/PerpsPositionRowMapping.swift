import Foundation
import PerpsModels
import TKLocalize

public enum PerpsPositionRowMapping {
    /// In the backend's order (largest position first), as on Android.
    public static func rows(
        from positions: [PerpsPositionSummary],
        format: PerpsFormatting,
        iconURL: (Int64) -> URL?
    ) -> [PerpsPositionRowItem] {
        positions.map { item(from: $0, format: format, iconURL: iconURL($0.marketId)) }
    }

    /// The wallet screen shows only the positions nearest to liquidation; the rest collapse into a "More Positions" row.
    public static func preview(
        from positions: [PerpsPositionSummary],
        limit: Int = 3,
        format: PerpsFormatting,
        iconURL: (Int64) -> URL?
    ) -> PerpsPositionsPreview {
        let sorted = positions.sorted(by: isNearerToLiquidation)
        let hidden = sorted.dropFirst(limit)
        return PerpsPositionsPreview(
            rows: sorted.prefix(limit).map { item(from: $0, format: format, iconURL: iconURL($0.marketId)) },
            more: hidden.isEmpty ? nil : PerpsMorePositions(iconURLs: hidden.prefix(2).map { iconURL($0.marketId) })
        )
    }

    private static func isNearerToLiquidation(_ lhs: PerpsPositionSummary, _ rhs: PerpsPositionSummary) -> Bool {
        switch (lhs.liquidationDistancePercent.map(abs), rhs.liquidationDistancePercent.map(abs)) {
        case let (left?, right?) where left != right:
            left < right
        case (.some, nil):
            true
        case (nil, .some):
            false
        default:
            lhs.marketId < rhs.marketId
        }
    }

    private static func item(
        from summary: PerpsPositionSummary,
        format: PerpsFormatting,
        iconURL: URL?
    ) -> PerpsPositionRowItem {
        PerpsPositionRowItem(
            id: summary.marketId,
            symbol: summary.symbol,
            iconURL: iconURL,
            leverageText: summary.leverage.map { format.leverage($0).uppercased() },
            sideText: (summary.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isLong: summary.side == .long,
            valueText: format.balance(summary.equityUsd),
            pnlText: format.signedBalance(summary.unrealizedPnlUsd),
            isPnlPositive: format.hiddenBalanceText == nil && summary.unrealizedPnlUsd != 0 ? summary.unrealizedPnlUsd > 0 : nil
        )
    }

    public static func total(positions: [PerpsPositionSummary], format: PerpsFormatting) -> PerpsPositionsTotal? {
        guard !positions.isEmpty else { return nil }
        if let hidden = format.hiddenBalanceText {
            return PerpsPositionsTotal(amountText: hidden, pnlText: hidden, pnlPercentText: nil, isPnlPositive: nil)
        }
        let amount = positions.reduce(0) { $0 + $1.equityUsd }
        let pnl = positions.reduce(0) { $0 + $1.unrealizedPnlUsd }
        let margin = positions.reduce(0) { $0 + $1.marginUsd }
        let everyPositionHasMargin = positions.allSatisfy { $0.marginUsd > 0 }
        return PerpsPositionsTotal(
            amountText: format.usd(amount),
            pnlText: format.signedUsd(pnl),
            pnlPercentText: everyPositionHasMargin ? format.signedPercent(pnl / margin * 100) : nil,
            isPnlPositive: pnl == 0 ? nil : pnl > 0
        )
    }
}
