import ChainKit
import Foundation
import TKLogging

/// One market read, kept so the figures a screen shows can be recomputed without
/// asking the network again. Submitting never goes through here: it plans against
/// a fresh read of its own, so this cannot put a stale figure on the wire.
final class PerpsSnapshotReviewer: PerpetualReviewer, @unchecked Sendable {
    /// How long a read is worth reusing. Well inside the planner's own freshness
    /// window, so a figure is replaced long before the planner would refuse it.
    private static let lifetimeMillis: Int64 = 5000

    private let host: PerpsPlannerHost
    private let intents: PerpsChainIntents
    private let inputs: PerpsReviewInputs

    var isStale: Bool {
        PerpsPlannerMapping.nowUnixMs() - inputs.context.nowUnixMs > Self.lifetimeMillis
    }

    init(host: PerpsPlannerHost, intents: PerpsChainIntents, inputs: PerpsReviewInputs) {
        self.host = host
        self.intents = intents
        self.inputs = inputs
    }

    func reviewOpen(_ intent: PerpsOpenMarketIntent) -> PerpsOpenOrderReview? {
        guard let margin = PerpsMarketMath.optionalDouble(intent.marginUsd), margin > 0 else { return nil }
        guard let review: PerpetualReview.Open = plan({
            try intents.open(intent, context: inputs.context, operationId: UUID().uuidString)
        }) else {
            return nil
        }
        return PerpsPlannerMapping.openReview(review, symbol: inputs.symbol, marginUsd: margin)
    }

    func reviewMarginChange(_ intent: PerpsMarginChangeIntent) -> PerpsMarginChangeReview? {
        guard let present = try? inputs.context.requirePosition() else { return nil }
        guard let review: PerpetualReview.Margin = plan({
            try intents.margin(
                intent,
                context: inputs.context,
                present: present,
                operationId: UUID().uuidString
            )
        }) else {
            return nil
        }
        return PerpsPlannerMapping.marginReview(
            review,
            symbol: inputs.symbol,
            direction: intent.direction,
            side: PerpsPlannerMapping.tradeSide(present.side),
            leverage: inputs.context.leverage,
            allocatedBefore: present.allocatedMarginQuote,
            liquidationBefore: present.liquidationPrice?.int64Value
        )
    }

    /// Synchronous by design: the planner is pure, so a recompute is arithmetic over
    /// inputs already in hand. A throw means those inputs no longer answer.
    private func plan<T>(_ intent: () throws -> PerpsTradeIntent) -> T? {
        do {
            let plan = try host.prepare(
                intent: intent(),
                context: inputs.context,
                marketSnapshot: inputs.marketSnapshot
            )
            return plan.review as? T
        } catch {
            Log.i("🪵 Perps: review unavailable — \(error)")
            return nil
        }
    }
}
