import ChainKit
import Foundation

enum PerpsLiquidationReasonMapper {
    static func map(_ reason: PerpsLiquidationUnavailable?) -> PerpsLiquidationUnavailableReason {
        guard let reason else { return .unknown }
        if reason === PerpsLiquidationUnavailable.flatposition { return .flatPosition }
        if reason === PerpsLiquidationUnavailable.missingmark { return .missingMark }
        if reason === PerpsLiquidationUnavailable.missingcollateral { return .missingCollateral }
        if reason === PerpsLiquidationUnavailable.missingmaintenancefraction { return .missingMaintenanceFraction }
        if reason === PerpsLiquidationUnavailable.zerodenominator { return .zeroDenominator }
        if reason === PerpsLiquidationUnavailable.negativeprice { return .negativePrice }
        return .unknown
    }
}

/// Cancel keys of the legs a change supersedes, kept by role: the SDK intent has
/// a slot per role and rejects a stop-loss offered as the replaced take-profit.
struct PerpsAutoCloseStaleLegs: Equatable {
    let takeProfit: Int64?
    let stopLoss: Int64?

    var indexes: [Int64] {
        Array(Set([takeProfit, stopLoss].compactMap { $0 })).sorted()
    }
}

enum PerpsAutoCloseTxPlan: Equatable {
    case replace(target: PerpsAutoClose, stale: PerpsAutoCloseStaleLegs)
    case clear(stale: PerpsAutoCloseStaleLegs)
    case noChange
}

/// An auto-close change translated into what the SDK intent needs, plus what the
/// journal needs to confirm it afterwards. A nil `pending` means the change asked
/// for nothing the venue does not already hold.
struct PerpsAutoCloseLegs {
    var takeProfit: PerpsAutoCloseLeg?
    var stopLoss: PerpsAutoCloseLeg?
    var replacedTakeProfit: KotlinLong?
    var replacedStopLoss: KotlinLong?
    var target: PerpsAutoClose?
    var pending: PerpsPendingAutoCloseChange?

    var spec: PerpsAutoCloseSpec? {
        guard takeProfit != nil || stopLoss != nil
            || replacedTakeProfit != nil || replacedStopLoss != nil
        else {
            return nil
        }
        return PerpsAutoCloseSpec(
            takeProfit: takeProfit,
            stopLoss: stopLoss,
            replacedTakeProfitOrderIndex: replacedTakeProfit,
            replacedStopLossOrderIndex: replacedStopLoss
        )
    }
}

public enum PerpsAutoCloseChangePlanner {
    static func plan(target: PerpsAutoClose, resting: [PerpsTriggerOrderSummary]) -> PerpsAutoCloseTxPlan {
        guard !matches(target: target, resting: resting) else { return .noChange }
        // Position-tied triggers expose a composite read `order_index` that is
        // not a cancel identity; prefer the client order index used at creation.
        let stale = PerpsAutoCloseStaleLegs(
            takeProfit: resting.first { $0.kind == .takeProfit }?.cancelKey,
            stopLoss: resting.first { $0.kind == .stopLoss }?.cancelKey
        )
        return target.isEmpty
            ? .clear(stale: stale)
            : .replace(target: target, stale: stale)
    }

    /// Confirmation predicate for the auto-close reconciliation. Set path: the live
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
        let live = Set(orders.map(\.cancelKey))
        return matches(target: target, resting: orders)
            && pending.restingOrderIndexes.allSatisfy { !live.contains($0) }
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

enum PerpsTradingErrorMapper {
    static func map(_ error: Error) -> PerpsTradingError {
        if let trading = error as? PerpsTradingError { return trading }
        if let api = error as? PerpsAPIError { return map(api) }
        if let execution = kotlinException(from: error, as: PerpsExecutionException.self) {
            return map(kind: execution.kind, message: execution.message ?? "execution failed")
        }
        if let trade = kotlinException(from: error, as: PerpsTradeException.self) {
            return map(kind: trade.kind, message: trade.message ?? "invalid transaction")
        }
        if let validation = lighterValidationException(from: error) {
            return .validation(validation.message ?? "invalid transaction")
        }
        if let network = mapNetworkError(error as NSError) { return network }
        return .unknown("\(error)")
    }

    private static func map(kind: PerpsTradeError, message: String) -> PerpsTradingError {
        if kind === PerpsTradeError.protocolfailure { return .protocolFailure(message) }
        if kind === PerpsTradeError.insufficientbalance { return .insufficientBalance }
        if kind === PerpsTradeError.insufficientliquidity
            || kind === PerpsTradeError.needsmoredepth
            || kind === PerpsTradeError.slippageexceeded
        {
            return .insufficientLiquidity
        }
        if kind === PerpsTradeError.noposition || kind === PerpsTradeError.ordernotfound {
            return .positionNotFound
        }
        if kind === PerpsTradeError.marginbelowrequirement { return .immediateLiquidationRisk }
        if kind === PerpsTradeError.tradingdisabled || kind === PerpsTradeError.unsupportedmarket {
            return .regionUnavailable
        }
        if kind === PerpsTradeError.staleinput
            || kind === PerpsTradeError.planexpired
            || kind === PerpsTradeError.positionchanged
            || kind === PerpsTradeError.unusablesnapshot
        {
            return .stalePreparedTransaction
        }
        return .validation(message)
    }

    private static func map(
        kind: PerpsExecutionErrorKind,
        message: String
    ) -> PerpsTradingError {
        switch kind {
        case .offline: return .offline
        case .timeout: return .timeout
        case .ratelimited: return .rateLimited
        case .serverunavailable: return .serverUnavailable
        case .serverrejected: return .serverRejected(message)
        case .authexpired: return .authExpired
        case .credentialsrevoked: return .credentialsRevoked
        case .activationrequired: return .activationRequired
        case .activationcanceled: return .activationCanceled
        case .regionunavailable: return .regionUnavailable
        case .validation: return .validation(message)
        case .nothingtochange: return .nothingToChange
        case .insufficientbalance: return .insufficientBalance
        case .insufficientliquidity: return .insufficientLiquidity
        case .positionnotfound: return .positionNotFound
        case .immediateliquidationrisk: return .immediateLiquidationRisk
        case .protocolfailure: return .protocolFailure(message)
        case .operationinprogress: return .operationInProgress
        case .stalepreparedtransaction: return .stalePreparedTransaction
        case .submitunknown: return .submitUnknown
        case .unknown: return .unknown(message)
        default: return .unknown(message)
        }
    }

    /// The service names the outcome twice: `details.reason` says what to do about
    /// a refused submission, and the envelope's `code` classifies everything else.
    /// `message` is fixed per code, so it is carried for logs and never matched on.
    static func map(_ failure: PerpsAPIFailure) -> PerpsTradingError {
        let text = failure.message ?? failure.code ?? "request failed"
        switch failure.reason {
        case "resign_required", "order_gone":
            return .stalePreparedTransaction
        case "invalid_transaction", "malformed_tx_info", "empty_batch", "foreign_account", "batch_not_accepted":
            return .protocolFailure(text)
        case "lighter_rejected":
            return .serverRejected(text)
        default:
            break
        }
        switch failure.code {
        case "validation_error":
            return .validation(text)
        case "conflict":
            return .stalePreparedTransaction
        case "token_expired", "invalid_token", "wallet_auth_required", "wallet_auth_invalid":
            return .authExpired
        case "token_revoked", "device_inactive":
            return .credentialsRevoked
        case "wallet_forbidden":
            return .regionUnavailable
        case "not_found":
            return .positionNotFound
        case "upstream_unavailable", "auth_unavailable":
            return .serverUnavailable
        default:
            break
        }
        if failure.httpStatus == 429 { return .rateLimited }
        if failure.httpStatus == 400 { return .validation(text) }
        return .serverUnavailable
    }

    static func map(_ api: PerpsAPIError) -> PerpsTradingError {
        switch api {
        case .unauthorized:
            return .authExpired
        case .conflict:
            return .stalePreparedTransaction
        case let .badStatus(failure):
            return map(failure)
        case let .transport(underlying):
            if let network = underlying.flatMap({ mapNetworkError($0 as NSError) }) {
                return network
            }
            return .serverUnavailable
        case .badUrl, .badResponse, .unknown, .notFound:
            return .serverUnavailable
        }
    }

    private static func lighterValidationException(from error: Error) -> LighterValidationException? {
        kotlinException(from: error, as: LighterValidationException.self)
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
