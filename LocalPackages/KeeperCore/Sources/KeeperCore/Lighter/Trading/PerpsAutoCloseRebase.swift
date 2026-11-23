import ChainKit
import Foundation
import PerpsModels
import TKPerpsAPI

enum PerpsAutoCloseRebase {
    /// How long after its entry operation settles a correction waits for the venue to catch up.
    /// A limit entry still resting past it fills at its own price, the one its legs were priced from.
    static let settleWindowMillis: Int64 = 2 * 60 * 1000

    static func followUps(
        pending: PerpsPendingTradingAction,
        planned: PerpsPlannedTrade,
        takeProfitROIPercent: Double?,
        stopLossROIPercent: Double?,
        leverage: Double?
    ) -> [PerpsPendingTradingAction] {
        let entry: (clientOrderIndex: Int64, autoClose: PerpsAutoCloseSpec?, takeProfit: KotlinLong?, stopLoss: KotlinLong?)
        switch (planned.intent, planned.plan.review) {
        case let (open as PerpsTradeIntent.Open, review as PerpetualReview.Open):
            entry = (open.clientOrderIndex, open.autoClose, review.takeProfitTrigger, review.stopLossTrigger)
        case let (add as PerpsTradeIntent.Add, review as PerpetualReview.Add):
            entry = (add.clientOrderIndex, add.autoClose, review.takeProfitTrigger, review.stopLossTrigger)
        default:
            return []
        }
        guard let leverage, leverage.isFinite, leverage > 0 else { return [] }
        var positionBaseBefore: Double?
        if case let .sizeChange(change, _) = pending.payload {
            positionBaseBefore = change.baseSizeBefore
        }
        let decimals = planned.context.rules.scale.priceDecimals
        let legs: [(PerpsPendingOrderRole, PerpsAutoCloseLeg?, Double?, KotlinLong?)] = [
            (.stopLoss, entry.autoClose?.stopLoss, stopLossROIPercent, entry.stopLoss),
            (.takeProfit, entry.autoClose?.takeProfit, takeProfitROIPercent, entry.takeProfit),
        ]
        return legs.compactMap { role, leg, roi, trigger -> PerpsPendingTradingAction? in
            guard let leg, let roi, roi.isFinite, let trigger else { return nil }
            return PerpsPendingTradingAction(
                operationId: "\(pending.operationId)/rebase/\(role.rawValue)",
                createdAtMillis: pending.createdAtMillis,
                walletId: pending.walletId,
                marketId: pending.marketId,
                side: pending.side,
                payload: .autoCloseRebase(PerpsPendingAutoCloseRebase(
                    parentOperationId: pending.operationId,
                    parentClientOrderIndex: entry.clientOrderIndex,
                    originalTriggerPrice: PerpsScaled.double(trigger.int64Value, decimals: decimals),
                    roiPercent: roi,
                    leverage: leverage,
                    positionBaseBefore: positionBaseBefore
                )),
                expiresAtMillis: pending.expiresAtMillis,
                orderRefs: [.init(role: role, clientOrderIndex: leg.clientOrderIndex)]
            )
        }
    }

    /// A working partial fill can still change its average entry. Keep its initial protection until terminal.
    static func finalFilledBase(_ orders: [Components.Schemas.PositionStateOrder]) -> Double? {
        guard let latest = orders.first,
              latest.status.lowercased() == "filled" || PerpsBackendMapping.isCanceled(latest) else { return nil }
        guard let filled = latest.filled_base.flatMap(Double.init), filled.isFinite, filled >= 0 else { return nil }
        return filled
    }

    static func targetPrice(
        _ rebase: PerpsPendingAutoCloseRebase,
        side: PerpsTradeSide,
        entryPrice: Double,
        priceDecimals: Int32,
        tick: Int64
    ) throws -> Int64 {
        guard entryPrice.isFinite, rebase.roiPercent.isFinite, rebase.leverage.isFinite, tick > 0,
              (0 ... 18).contains(priceDecimals),
              let price = PerpsTriggerROI.triggerPrice(
                  side: side, entryPrice: entryPrice, leverage: rebase.leverage, percent: rebase.roiPercent
              ), price.isFinite, price > 0 else { throw PerpsTradingError.validation("invalid TP/SL ROI") }
        var ticks = Decimal(price) * pow(Decimal(10), Int(priceDecimals)) / Decimal(tick)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &ticks, 0, .plain)
        let scaled = rounded * Decimal(tick)
        guard !scaled.isNaN, scaled > 0, scaled <= Decimal(Int64.max) else {
            throw PerpsTradingError.validation("invalid TP/SL tick")
        }
        return NSDecimalNumber(decimal: scaled).int64Value
    }
}
