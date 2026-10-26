import Foundation
import PerpsModels
import TKLocalize

public enum PerpsPositionRowMapping {
    public static func rows(
        from positions: [PerpsPositionSummary],
        format: PerpsFormatting,
        iconURL: (Int64) -> URL?,
        hiddenValueText: String? = nil
    ) -> [PerpsPositionRowItem] {
        positions
            .sorted { $0.marketId < $1.marketId }
            .map { item(from: $0, format: format, iconURL: iconURL($0.marketId), hiddenValueText: hiddenValueText) }
    }

    private static func item(
        from summary: PerpsPositionSummary,
        format: PerpsFormatting,
        iconURL: URL?,
        hiddenValueText: String?
    ) -> PerpsPositionRowItem {
        PerpsPositionRowItem(
            id: summary.marketId,
            symbol: summary.symbol,
            iconURL: iconURL,
            leverageText: summary.leverage.map { format.leverage($0).uppercased() },
            sideText: (summary.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isLong: summary.side == .long,
            valueText: hiddenValueText ?? format.usd(summary.equityUsd),
            pnlText: hiddenValueText ?? format.signedUsd(summary.unrealizedPnlUsd),
            isPnlPositive: hiddenValueText == nil ? summary.unrealizedPnlUsd >= 0 : nil
        )
    }

    public static func total(positions: [PerpsPositionSummary], format: PerpsFormatting) -> PerpsPositionsTotal? {
        guard !positions.isEmpty else { return nil }
        let amount = positions.reduce(0) { $0 + $1.equityUsd }
        let pnl = positions.reduce(0) { $0 + $1.unrealizedPnlUsd }
        let margin = positions.reduce(0) { $0 + $1.marginUsd }
        let everyPositionHasMargin = positions.allSatisfy { $0.marginUsd > 0 }
        return PerpsPositionsTotal(
            amountText: format.usd(amount),
            pnlText: format.signedUsd(pnl),
            pnlPercentText: everyPositionHasMargin ? format.signedPercent(pnl / margin * 100) : nil,
            isPnlPositive: pnl >= 0
        )
    }
}
