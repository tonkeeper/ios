import ChainKit
import Foundation

enum PerpsTradeSideMapper {
    static func toChainKit(_ side: PerpsTradeSide) -> LighterTradeSide {
        switch side {
        case .long: return LighterTradeSide.long_
        case .short: return LighterTradeSide.short_
        }
    }

    static func fromChainKit(_ side: LighterTradeSide) -> PerpsTradeSide {
        side === LighterTradeSide.short_ ? .short : .long
    }
}

enum PerpsLiquidationReasonMapper {
    static func map(_ reason: LighterLiquidationUnavailable?) -> PerpsLiquidationUnavailableReason {
        guard let reason else { return .unknown }
        if reason === LighterLiquidationUnavailable.flatPosition { return .flatPosition }
        if reason === LighterLiquidationUnavailable.missingMark { return .missingMark }
        if reason === LighterLiquidationUnavailable.missingCollateral { return .missingCollateral }
        if reason === LighterLiquidationUnavailable.missingMaintenanceFraction { return .missingMaintenanceFraction }
        if reason === LighterLiquidationUnavailable.zeroDenominator { return .zeroDenominator }
        if reason === LighterLiquidationUnavailable.negativePrice { return .negativePrice }
        return .unknown
    }
}

enum PerpsOpenOrderReviewMapper {
    static func map(
        review: LighterOrderReview,
        marginUsd: Double
    ) -> PerpsOpenOrderReview {
        PerpsOpenOrderReview(
            symbol: review.symbol,
            marginUsd: marginUsd,
            entryPrice: review.estimatedEntryPrice?.doubleValue ?? review.priceHuman,
            liquidationPrice: review.estimatedLiquidationPrice?.doubleValue,
            notionalUsd: review.notionalUsd,
            baseSize: review.baseSize,
            estimatedFeeUsd: review.estimatedFeeUsd?.doubleValue,
            liquidationUnavailableReason: review.estimatedLiquidationPrice == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil
        )
    }
}

enum PerpsCloseReviewMapper {
    static func map(review: LighterOrderReview, position: LighterOpenPosition) -> PerpsCloseReview {
        let estimatedBaseFilled = review.estimatedBaseFilled?.doubleValue ?? review.baseSize
        let closedPortion = position.size > 0 ? min(1, estimatedBaseFilled / abs(position.size)) : 0
        let marginUsd = position.allocatedMargin * closedPortion
        let positionNotional = abs(position.size) * position.avgEntryPrice
        let fallbackLeverage: Double? = position.allocatedMargin > 0
            ? (positionNotional / position.allocatedMargin).rounded()
            : nil
        return PerpsCloseReview(
            symbol: review.symbol,
            side: PerpsTradeSideMapper.fromChainKit(position.side),
            leverage: position.leverage?.doubleValue ?? fallbackLeverage,
            marginUsd: marginUsd,
            notionalUsd: review.notionalUsd,
            baseSize: estimatedBaseFilled,
            estimatedFeeUsd: review.estimatedFeeUsd?.doubleValue,
            estimatedPnlUsd: review.estimatedPnlUsd?.doubleValue,
            estimatedReceiveUsd: review.estimatedReceiveUsd?.doubleValue
        )
    }
}

enum PerpsSizeChangeReviewMapper {
    /// Old values are entry-cost based (size × avg entry), not mark-based: the design
    /// frames Size as margin × leverage, which only holds at the position's entry.
    static func map(
        direction: PerpsSizeChangeDirection,
        review: LighterOrderReview,
        position: LighterOpenPosition,
        marginDeltaUsd: Double
    ) -> PerpsSizeChangeReview {
        let positionSize = abs(position.size)
        let oldEntry = position.avgEntryPrice
        let oldNotional = positionSize * oldEntry
        let chunkBase = abs(review.baseSize)

        let newEntry: Double
        let newNotional: Double
        let newBase: Double
        switch direction {
        case .add:
            if let projected = review.positionAfter {
                newBase = abs(projected.baseSize)
                newEntry = projected.entryPrice
                newNotional = newBase * newEntry
            } else {
                newBase = positionSize + chunkBase
                newEntry = newBase > 0
                    ? (positionSize * oldEntry + chunkBase * review.priceHuman) / newBase
                    : oldEntry
                newNotional = oldNotional + review.notionalUsd
            }
        case .reduce:
            newBase = abs(review.positionAfter?.baseSize ?? max(0, positionSize - chunkBase))
            newEntry = review.positionAfter?.entryPrice ?? oldEntry
            newNotional = newBase * newEntry
        }

        let marginUsd = position.allocatedMargin
        let fallbackLeverage: Double? = marginUsd > 0 ? (oldNotional / marginUsd).rounded() : nil

        return PerpsSizeChangeReview(
            symbol: review.symbol,
            direction: direction,
            side: PerpsTradeSideMapper.fromChainKit(position.side),
            leverage: position.leverage?.doubleValue ?? fallbackLeverage,
            marginDeltaUsd: marginDeltaUsd,
            entryPrice: PerpsValueChange(old: oldEntry, new: newEntry),
            notionalUsd: PerpsValueChange(old: oldNotional, new: newNotional),
            baseSize: PerpsValueChange(old: positionSize, new: newBase),
            liquidationPrice: review.estimatedLiquidationPrice?.doubleValue,
            liquidationUnavailableReason: review.estimatedLiquidationPrice == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil,
            estimatedFeeUsd: review.estimatedFeeUsd?.doubleValue
        )
    }
}

enum PerpsMarginChangeReviewMapper {
    static func map(
        direction: PerpsMarginChangeDirection,
        review: LighterMarginReview,
        position: LighterOpenPosition
    ) -> PerpsMarginChangeReview {
        let marginBefore = review.allocatedMarginBefore?.doubleValue ?? position.allocatedMargin
        let signedDelta = direction == .add ? review.usdc : -review.usdc
        let marginAfter = review.allocatedMarginAfter?.doubleValue ?? (marginBefore + signedDelta)

        let liquidationBefore = review.liquidationPriceBefore?.doubleValue
            ?? (position.liquidationPrice > 0 ? position.liquidationPrice : nil)
        let liquidationAfter = review.estimatedLiquidationPriceAfter?.doubleValue
        let liquidationChange: PerpsValueChange? = liquidationAfter.map {
            PerpsValueChange(old: liquidationBefore ?? $0, new: $0)
        }

        let fallbackLeverage: Double? = marginBefore > 0
            ? (abs(position.size) * position.avgEntryPrice / marginBefore).rounded()
            : nil

        return PerpsMarginChangeReview(
            symbol: position.symbol,
            direction: direction,
            side: PerpsTradeSideMapper.fromChainKit(position.side),
            leverage: position.leverage?.doubleValue ?? fallbackLeverage,
            amountUsd: review.usdc,
            allocatedMargin: PerpsValueChange(old: marginBefore, new: marginAfter),
            liquidationPrice: liquidationChange,
            liquidationUnavailableReason: liquidationAfter == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil,
            isImmediateRisk: review.isImmediateRisk
        )
    }
}

enum PerpsAutoCloseTxPlan: Equatable {
    case replace(target: PerpsAutoClose, staleOrderIndexes: [Int64])
    case clear(orderIndexes: [Int64])
    case noChange
}

public enum PerpsAutoCloseChangePlanner {
    static func plan(target: PerpsAutoClose, resting: [PerpsTriggerOrderSummary]) -> PerpsAutoCloseTxPlan {
        guard !matches(target: target, resting: resting) else { return .noChange }
        // Position-tied triggers expose a composite read `order_index` that is
        // not a cancel identity; prefer the client order index used at creation.
        let indexes = Array(Set(resting.map(\.cancelKey))).sorted()
        return target.isEmpty
            ? .clear(orderIndexes: indexes)
            : .replace(target: target, staleOrderIndexes: indexes)
    }

    /// Confirmation predicate for `reconcileAutoCloseChange`. Set path: the live
    /// legs must match the target exactly (leg kinds + rounded trigger prices) —
    /// a venue that stacked instead of replacing leaves extra legs and honestly
    /// never confirms. Cancel path: the resting indexes are gone — a leg that
    /// *fired* reads the same as a canceled one, and either way the reloaded
    /// orders are the truth.
    static func isConfirmed(pending: PerpsPendingAutoCloseChange, orders: [PerpsTriggerOrderSummary]) -> Bool {
        guard let target = pending.target else {
            // Same identity as `plan`: restingOrderIndexes carry cancel keys.
            let live = Set(orders.map(\.cancelKey))
            return pending.restingOrderIndexes.allSatisfy { !live.contains($0) }
        }
        return matches(target: target, resting: orders)
    }

    public static func matches(target: PerpsAutoClose, resting: [PerpsTriggerOrderSummary]) -> Bool {
        legMatches(target.takeProfit, resting.filter { $0.kind == .takeProfit })
            && legMatches(target.stopLoss, resting.filter { $0.kind == .stopLoss })
    }

    private static func legMatches(_ expected: PerpsAutoCloseTrigger?, _ legs: [PerpsTriggerOrderSummary]) -> Bool {
        guard let expected else { return legs.isEmpty }
        guard legs.count == 1, let leg = legs.first else { return false }
        return abs(leg.triggerPrice - expected.triggerPrice) <= max(1e-9, expected.triggerPrice * 1e-6)
    }
}

enum PerpsAutoCloseChangeReviewMapper {
    static func map(review: LighterTpSlReview, position: LighterOpenPosition) -> PerpsAutoCloseChangeReview {
        PerpsAutoCloseChangeReview(
            side: PerpsTradeSideMapper.fromChainKit(position.side),
            new: PerpsAutoClose(
                takeProfit: review.takeProfit.map(trigger),
                stopLoss: review.stopLoss.map(trigger)
            )
        )
    }

    static func mapCancel(position: LighterOpenPosition) -> PerpsAutoCloseChangeReview {
        PerpsAutoCloseChangeReview(side: PerpsTradeSideMapper.fromChainKit(position.side), new: nil)
    }

    private static func trigger(_ leg: LighterAutoCloseReview) -> PerpsAutoCloseTrigger {
        PerpsAutoCloseTrigger(triggerPrice: leg.triggerPrice)
    }
}

enum PerpsTradingErrorMapper {
    static func map(_ error: Error) -> PerpsTradingError {
        if let trading = error as? PerpsTradingError { return trading }
        if operationBlockedException(from: error) != nil { return .operationInProgress }
        if sessionException(from: error) != nil { return .credentialsRevoked }
        if let operation = operationException(from: error) {
            guard operation.operationState === LighterOperationState.failed else {
                return .submitUnknown
            }
            return map(
                kind: operation.kind,
                message: operation.message ?? "operation failed",
                isInsufficientBalance: operation.isInsufficientBalance
            )
        }
        if let validation = lighterValidationException(from: error) {
            let kind = validation.kind
            if kind === LighterValidationKind.noPosition { return .positionNotFound }
            if kind === LighterValidationKind.insufficientLiquidity
                || kind === LighterValidationKind.slippageBound
            {
                return .insufficientLiquidity
            }
            return .validation(validation.message ?? "invalid transaction")
        }
        if let api = lighterApiException(from: error) {
            return map(
                kind: api.kind,
                message: api.message ?? "request failed",
                isInsufficientBalance: api.isInsufficientBalance
            )
        }
        if let network = mapNetworkError(error as NSError) { return network }
        return .unknown("\(error)")
    }

    static func map(_ failure: LighterOperationFailure) -> PerpsTradingError {
        let insufficientCodes = [
            LighterErrorCodes.shared.NOT_ENOUGH_COLLATERAL,
            LighterErrorCodes.shared.NOT_ENOUGH_ASSET_BALANCE,
            LighterErrorCodes.shared.NOT_ENOUGH_ASSET_BALANCE_FOR_FEE,
        ]
        let isInsufficientBalance = failure.lighterCode
            .map { insufficientCodes.contains($0.int32Value) } ?? false
        return map(
            kind: failure.kind,
            message: failure.message,
            isInsufficientBalance: isInsufficientBalance
        )
    }

    private static func map(
        kind: LighterErrorKind,
        message: String,
        isInsufficientBalance: Bool
    ) -> PerpsTradingError {
        if isInsufficientBalance { return .insufficientBalance }
        if kind === LighterErrorKind.offline { return .offline }
        if kind === LighterErrorKind.timeout { return .timeout }
        if kind === LighterErrorKind.rateLimited { return .rateLimited }
        if kind === LighterErrorKind.serverUnavailable { return .serverUnavailable }
        if kind === LighterErrorKind.serverRejected { return .serverRejected(message) }
        if kind === LighterErrorKind.auth { return .authExpired }
        // `LighterErrorKind.protocol` is not importable from Swift (keyword-named Kotlin enum entry).
        if kind.name == "protocol" { return .protocolFailure(message) }
        return .unknown(message)
    }

    static func operationBlockedException(from error: Error) -> LighterOperationBlockedException? {
        kotlinException(from: error, as: LighterOperationBlockedException.self)
    }

    private static func lighterApiException(from error: Error) -> LighterApiException? {
        kotlinException(from: error, as: LighterApiException.self)
    }

    private static func lighterValidationException(from error: Error) -> LighterValidationException? {
        kotlinException(from: error, as: LighterValidationException.self)
    }

    private static func operationException(from error: Error) -> LighterOperationException? {
        kotlinException(from: error, as: LighterOperationException.self)
    }

    private static func sessionException(from error: Error) -> LighterSessionException? {
        kotlinException(from: error, as: LighterSessionException.self)
    }

    private static func mapNetworkError(_ error: NSError) -> PerpsTradingError? {
        guard error.domain == NSURLErrorDomain else { return nil }
        switch error.code {
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorDataNotAllowed,
             NSURLErrorInternationalRoamingOff:
            return .offline
        case NSURLErrorBadServerResponse:
            return .serverUnavailable
        default:
            return nil
        }
    }

    private static func kotlinException<T>(from error: Error, as type: T.Type) -> T? {
        if let typed = error as? T { return typed }
        return (error as NSError).userInfo["KotlinException"] as? T
    }
}
