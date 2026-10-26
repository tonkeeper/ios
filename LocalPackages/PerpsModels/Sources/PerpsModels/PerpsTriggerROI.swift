import Foundation

/// A TP/SL leg's ROI on the initial margin — the entry notional over leverage,
/// i.e. the price move times leverage. The venue's margin drifts with the mark
/// (cross) and with funding (isolated); this does not, so a resting trigger keeps
/// reading as the same percent for as long as the position's entry and leverage hold.
public enum PerpsTriggerROI {
    public static func pnlUsd(
        side: PerpsTradeSide,
        entryPrice: Double,
        baseAmount: Double,
        triggerPrice: Double
    ) -> Double {
        direction(side) * (triggerPrice - entryPrice) * baseAmount
    }

    public static func percent(
        side: PerpsTradeSide,
        entryPrice: Double,
        leverage: Double,
        triggerPrice: Double
    ) -> Double? {
        guard entryPrice > 0, leverage > 0 else { return nil }
        return direction(side) * (triggerPrice / entryPrice - 1) * leverage * 100
    }

    public static func triggerPrice(
        side: PerpsTradeSide,
        entryPrice: Double,
        leverage: Double,
        percent: Double
    ) -> Double? {
        guard entryPrice > 0, leverage > 0 else { return nil }
        return entryPrice * (1 + direction(side) * percent / 100 / leverage)
    }

    private static func direction(_ side: PerpsTradeSide) -> Double {
        side == .long ? 1 : -1
    }
}
