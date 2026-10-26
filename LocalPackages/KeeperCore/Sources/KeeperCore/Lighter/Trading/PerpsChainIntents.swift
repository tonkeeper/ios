import ChainKit
import Foundation
import PerpsModels

/// Turns a user intent plus one market read into the intent the SDK planner takes.
/// Shared by review and submission, so the figure shown to the user and the trade
/// actually signed are built by the same code.
struct PerpsChainIntents {
    let config: PerpsTradingConfig

    func open(
        _ intent: PerpsOpenMarketIntent,
        context: PerpsMarketContext,
        operationId: String,
        clientOrderIndices: PerpsClientOrderIndices
    ) throws -> PerpsTradeIntent {
        let now = PerpsPlannerMapping.nowUnixMs()
        let priceDecimals = context.rules.scale.priceDecimals
        let order: PerpsOrderSpec
        if let limitPrice = intent.limitPrice, limitPrice > 0 {
            order = try PerpsOrderSpec.Limit(
                limitPrice: PerpsScaled.scale(limitPrice, decimals: priceDecimals, rounding: .nearest),
                postOnly: false,
                orderExpiryUnixMs: orderExpiryUnixMs(now: now)
            )
        } else {
            order = PerpsOrderSpec.Market(
                maxSlippagePpm: KotlinLong(value: PerpsPlannerMapping.slippagePpm(intent.maxSlippage)),
                slippageUtilizationPpm: 0,
                marginSafetyBufferPpm: 0
            )
        }
        return try PerpsTradeIntent.Open(
            operationId: operationId,
            scope: context.scope,
            marketId: intent.marketId,
            side: PerpsPlannerMapping.side(intent.side),
            marginBudgetQuote: PerpsScaled.parse(
                intent.marginUsd,
                decimals: context.rules.scale.quoteDecimals,
                rounding: .down
            ),
            initialMarginBps: PerpsPlannerMapping.initialMarginBps(leverage: intent.leverage),
            clientOrderIndex: clientOrderIndices.order,
            order: order,
            autoClose: autoCloseSpec(
                intent.autoClose,
                now: now,
                priceDecimals: priceDecimals,
                clientOrderIndices: clientOrderIndices
            )
        )
    }

    func margin(
        _ intent: PerpsMarginChangeIntent,
        context: PerpsMarketContext,
        present: PerpsPositionState.Present,
        operationId: String
    ) throws -> PerpsTradeIntent {
        let amountQuote = try PerpsScaled.parse(
            intent.amountUsd,
            decimals: context.rules.scale.quoteDecimals,
            rounding: .down
        )
        if intent.direction == .reduce, amountQuote >= present.allocatedMarginQuote {
            throw PerpsTradingError.validation("amount exceeds position margin")
        }
        return PerpsTradeIntent.Margin(
            operationId: operationId,
            scope: context.scope,
            marketId: intent.marketId,
            positionId: present.positionId,
            amountQuote: amountQuote,
            addToPosition: intent.direction == .add
        )
    }

    /// The one translation of an auto-close change, whether it is the whole operation
    /// or rides along with a size change; what to do with a change that asks for
    /// nothing is left to the caller.
    func autoCloseLegs(
        _ update: PerpsAutoCloseUpdate,
        context: PerpsMarketContext,
        now: Int64,
        clientOrderIndices: PerpsClientOrderIndices,
        renewsExpiry: Bool = false
    ) throws -> PerpsAutoCloseLegs {
        let target: PerpsAutoClose
        switch update {
        case .unchanged:
            return PerpsAutoCloseLegs()
        case .clear:
            target = PerpsAutoClose(takeProfit: nil, stopLoss: nil)
        case let .replace(value):
            target = value
        }
        let priceDecimals = context.rules.scale.priceDecimals
        switch PerpsAutoCloseChangePlanner.plan(
            target: target,
            resting: restingTriggerOrders(context),
            renewsExpiry: renewsExpiry
        ) {
        case .noChange:
            return PerpsAutoCloseLegs(target: target.isEmpty ? nil : target)
        case let .replace(normalized, stale):
            return try PerpsAutoCloseLegs(
                takeProfit: autoCloseLeg(
                    normalized.takeProfit,
                    now: now,
                    clientOrderIndex: clientOrderIndices.takeProfit,
                    priceDecimals: priceDecimals
                ),
                stopLoss: autoCloseLeg(
                    normalized.stopLoss,
                    now: now,
                    clientOrderIndex: clientOrderIndices.stopLoss,
                    priceDecimals: priceDecimals
                ),
                replacedTakeProfit: stale.takeProfit.map { KotlinLong(value: $0) },
                replacedStopLoss: stale.stopLoss.map { KotlinLong(value: $0) },
                target: normalized,
                pending: PerpsPendingAutoCloseChange(target: normalized, restingOrderIndexes: stale.indexes)
            )
        case let .clear(stale):
            return PerpsAutoCloseLegs(
                replacedTakeProfit: stale.takeProfit.map { KotlinLong(value: $0) },
                replacedStopLoss: stale.stopLoss.map { KotlinLong(value: $0) },
                pending: PerpsPendingAutoCloseChange(target: nil, restingOrderIndexes: stale.indexes)
            )
        }
    }

    func restingTriggerOrders(_ context: PerpsMarketContext) -> [PerpsTriggerOrderSummary] {
        context.accountSnapshot.restingOrders.compactMap { order in
            let kind: PerpsTriggerOrderSummary.Kind
            if order.category == .takeprofit {
                kind = .takeProfit
            } else if order.category == .stoploss {
                kind = .stopLoss
            } else {
                return nil
            }
            guard let trigger = order.triggerPrice else { return nil }
            return PerpsTriggerOrderSummary(
                orderIndex: order.orderIndex,
                clientOrderIndex: order.clientOrderIndex?.int64Value ?? 0,
                kind: kind,
                side: PerpsPlannerMapping.tradeSide(order.side),
                triggerPrice: PerpsScaled.double(trigger.int64Value, decimals: context.rules.scale.priceDecimals),
                baseAmount: PerpsScaled.double(order.remainingBaseAmount, decimals: context.rules.scale.baseDecimals),
                expiresAtSeconds: (order.expiryUnixMs?.int64Value ?? 0) / 1000
            )
        }
    }

    /// Review-only scopes never sign, so their indices stay off the disk.
    func clientOrderIndices(for context: PerpsMarketContext) async throws -> PerpsClientOrderIndices {
        if context.scope.isReviewOnly {
            return try PerpsPlannerMapping.reviewClientOrderIndices()
        }
        return try await PerpsPlannerMapping.reserveClientOrderIndices()
    }

    func orderExpiryUnixMs(now: Int64) -> Int64 {
        min(now + 28 * 24 * 60 * 60 * 1000, LighterConstants.shared.MaxTimestamp)
    }

    private func autoCloseSpec(
        _ autoClose: PerpsAutoClose?,
        now: Int64,
        priceDecimals: Int32,
        clientOrderIndices: PerpsClientOrderIndices
    ) throws -> PerpsAutoCloseSpec? {
        guard let autoClose, !autoClose.isEmpty else { return nil }
        return try PerpsAutoCloseSpec(
            takeProfit: autoCloseLeg(
                autoClose.takeProfit,
                now: now,
                clientOrderIndex: clientOrderIndices.takeProfit,
                priceDecimals: priceDecimals
            ),
            stopLoss: autoCloseLeg(
                autoClose.stopLoss,
                now: now,
                clientOrderIndex: clientOrderIndices.stopLoss,
                priceDecimals: priceDecimals
            ),
            replacedTakeProfitOrderIndex: nil,
            replacedStopLossOrderIndex: nil
        )
    }

    private func autoCloseLeg(
        _ trigger: PerpsAutoCloseTrigger?,
        now: Int64,
        clientOrderIndex: Int64,
        priceDecimals: Int32
    ) throws -> PerpsAutoCloseLeg? {
        guard let trigger else { return nil }
        return try PerpsAutoCloseLeg(
            triggerPrice: PerpsScaled.scale(trigger.triggerPrice, decimals: priceDecimals, rounding: .nearest),
            maxSlippagePpm: nil,
            expiryUnixMs: orderExpiryUnixMs(now: now),
            clientOrderIndex: clientOrderIndex
        )
    }
}

extension PerpsMarketContext {
    func requirePosition() throws -> PerpsPositionState.Present {
        guard let present = accountSnapshot.position as? PerpsPositionState.Present else {
            throw PerpsTradingError.positionNotFound
        }
        return present
    }
}
