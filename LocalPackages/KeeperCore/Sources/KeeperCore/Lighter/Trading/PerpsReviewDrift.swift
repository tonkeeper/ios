import Foundation
import PerpsModels

/// Bounds market movement between the last displayed review and signing.
enum PerpsReviewDrift {
    /// The share Android allows too (TK-5342).
    static let tolerance = 0.02

    static func near(_ shown: Double?, _ signed: Double?) -> Bool {
        guard let shown, let signed else { return shown == nil && signed == nil }
        guard shown.isFinite, signed.isFinite else { return false }
        return abs(signed - shown) <= abs(shown) * tolerance
    }

    /// A cent either way: amounts shown rounded to the cent are not a drift on their own.
    static func nearUsd(_ shown: Double?, _ signed: Double?) -> Bool {
        guard let shown, let signed else { return shown == nil && signed == nil }
        guard shown.isFinite, signed.isFinite else { return false }
        return abs(signed - shown) <= max(abs(shown) * tolerance, 0.01)
    }
}

extension PerpsOpenOrderReview {
    func admits(_ signed: PerpsOpenOrderReview) -> Bool {
        setsIsolatedMargin == signed.setsIsolatedMargin
            && PerpsReviewDrift.near(baseSize, signed.baseSize)
            && PerpsReviewDrift.nearUsd(notionalUsd, signed.notionalUsd)
            && PerpsReviewDrift.near(entryPrice, signed.entryPrice)
            && PerpsReviewDrift.near(worstPrice, signed.worstPrice)
            && PerpsReviewDrift.near(liquidationPrice, signed.liquidationPrice)
            && PerpsReviewDrift.nearUsd(marginUsd, signed.marginUsd)
            && PerpsReviewDrift.nearUsd(estimatedFeeUsd, signed.estimatedFeeUsd)
            && feeRatePercent == signed.feeRatePercent
    }
}

extension PerpsCloseReview {
    func admits(_ signed: PerpsCloseReview) -> Bool {
        side == signed.side
            && leverage == signed.leverage
            && PerpsReviewDrift.nearUsd(marginUsd, signed.marginUsd)
            && PerpsReviewDrift.near(baseSize, signed.baseSize)
            && PerpsReviewDrift.nearUsd(notionalUsd, signed.notionalUsd)
            && PerpsReviewDrift.near(worstPrice, signed.worstPrice)
            && PerpsReviewDrift.nearUsd(estimatedFeeUsd, signed.estimatedFeeUsd)
            && feeRatePercent == signed.feeRatePercent
    }
}

extension PerpsSizeChangeReview {
    func admits(_ signed: PerpsSizeChangeReview) -> Bool {
        direction == signed.direction
            && side == signed.side
            && leverage == signed.leverage
            && closesWholePosition == signed.closesWholePosition
            && PerpsReviewDrift.near(baseSize.old, signed.baseSize.old)
            && PerpsReviewDrift.near(baseSize.new, signed.baseSize.new)
            && PerpsReviewDrift.near(baseSize.new - baseSize.old, signed.baseSize.new - signed.baseSize.old)
            && PerpsReviewDrift.nearUsd(notionalUsd.new, signed.notionalUsd.new)
            && PerpsReviewDrift.near(entryPrice.new, signed.entryPrice.new)
            && PerpsReviewDrift.near(worstPrice, signed.worstPrice)
            && PerpsReviewDrift.near(liquidationPrice?.new, signed.liquidationPrice?.new)
            && PerpsReviewDrift.nearUsd(marginDeltaUsd, signed.marginDeltaUsd)
            && PerpsReviewDrift.nearUsd(estimatedFeeUsd, signed.estimatedFeeUsd)
            && feeRatePercent == signed.feeRatePercent
    }
}

extension PerpsMarginChangeReview {
    func admits(_ signed: PerpsMarginChangeReview) -> Bool {
        direction == signed.direction
            && side == signed.side
            && leverage == signed.leverage
            && PerpsReviewDrift.nearUsd(amountUsd, signed.amountUsd)
            && PerpsReviewDrift.nearUsd(allocatedMargin.old, signed.allocatedMargin.old)
            && PerpsReviewDrift.nearUsd(allocatedMargin.new, signed.allocatedMargin.new)
            && PerpsReviewDrift.near(liquidationPrice?.new, signed.liquidationPrice?.new)
    }
}
