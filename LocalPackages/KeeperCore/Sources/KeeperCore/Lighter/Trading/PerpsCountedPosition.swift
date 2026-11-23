import Foundation
import PerpsModels

/// The position tk-perps counted from its own fills, read with the open's state.
/// It lets an opening show the position before the portfolio read comes back.
struct PerpsCountedPosition: Equatable, Sendable {
    let baseSize: Double
    let entryPrice: Double
    let leverage: Double?
    let isolatedMarginUsd: Double?
    var markPrice: Double?

    /// The liquidation price is the review's estimate; the venue has no number for it
    /// here. The next portfolio read replaces the whole summary.
    func summary(_ opening: PerpsOpeningDescriptor, liquidationPrice: Double) -> PerpsPositionSummary {
        let leverage = leverage ?? opening.leverage
        let notional = baseSize * entryPrice
        let margin = isolatedMarginUsd ?? (leverage > 0 ? notional / leverage : opening.marginUsd)
        let mark = markPrice ?? entryPrice
        let pnl = (mark - entryPrice) * baseSize * (opening.side == .long ? 1 : -1)
        return PerpsPositionSummary(
            positionId: PerpsPlannerMapping.tkPositionId(marketId: opening.marketId),
            marketId: opening.marketId,
            symbol: opening.symbol,
            side: opening.side,
            baseSize: baseSize,
            notionalUsd: mark * baseSize,
            marginUsd: margin,
            equityUsd: margin + pnl,
            leverage: leverage,
            roiPercent: margin > 0 ? pnl / margin * 100 : nil,
            entryPrice: entryPrice,
            liquidationPrice: liquidationPrice,
            unrealizedPnlUsd: pnl,
            realizedPnlUsd: 0,
            fundingPaidUsd: nil,
            liquidationDistancePercent: nil,
            markPrice: markPrice
        )
    }
}
