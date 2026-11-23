import Foundation
import PerpsModels
import TKLogging

extension PerpsTradingError: @retroactive PerpsOperationLoggableError {
    public var operationLogSource: String {
        switch self {
        case .offline, .timeout: "network"
        case .credentialsRevoked, .activationRequired, .insufficientBalance: "wallet"
        case .activationCanceled: "user_or_lifecycle"
        case .serverUnavailable, .serverRejected, .rateLimited, .authExpired, .regionUnavailable, .tradingUnavailable: "lighter_or_backend"
        case .protocolFailure: "backend_or_client_contract"
        case .submitUnknown, .unknown: "unknown"
        default: "client"
        }
    }

    public var operationLogFields: [String: String] {
        var fields = ["domain_error": Mirror(reflecting: self).children.first?.label ?? String(describing: self)]
        switch self {
        case let .validation(reason), let .protocolFailure(reason), let .serverRejected(reason):
            fields["detail"] = String(reason.prefix(512))
        default:
            break
        }
        return fields
    }
}

extension PerpsOpenMarketIntent {
    var operationLogFields: [String: String] {
        var fields = ["market_id": String(marketId), "action": "open", "side": side.rawValue,
                      "margin_usd": marginUsd, "leverage": String(leverage), "max_slippage": String(maxSlippage),
                      "order_type": limitPrice == nil ? "market" : "limit"]
        fields["limit_price"] = limitPrice.map { String($0) }
        fields["take_profit"] = autoClose?.takeProfit.map { String($0.triggerPrice) }
        fields["stop_loss"] = autoClose?.stopLoss.map { String($0.triggerPrice) }
        return fields
    }
}

extension PerpsSizeChangeIntent {
    var operationLogFields: [String: String] {
        ["market_id": String(marketId), "action": "size_change", "direction": direction.rawValue, "margin_delta_usd": marginDeltaUsd]
    }
}

extension PerpsMarginChangeIntent {
    var operationLogFields: [String: String] {
        ["market_id": String(marketId), "action": "margin_change", "direction": direction.rawValue, "amount_usd": amountUsd]
    }
}

extension PerpsAutoCloseChangeIntent {
    var operationLogFields: [String: String] {
        ["market_id": String(marketId), "action": "auto_close_change", "take_profit": target.takeProfit.map { String($0.triggerPrice) } ?? "none",
         "stop_loss": target.stopLoss.map { String($0.triggerPrice) } ?? "none", "renews_expiry": String(renewsExpiry)]
    }
}

extension PerpsLimitOrderChangeIntent {
    var operationLogFields: [String: String] {
        ["market_id": String(marketId), "action": "limit_order_change", "change": kind.rawValue,
         "order_index": String(orderIndex), "limit_price": limitPrice.map { String($0) } ?? "none"]
    }
}

extension PerpsPreparedAction {
    var operationLogFields: [String: String] {
        var fields = ["flow": "trade", "operation_id": operationId, "wallet_id": walletId, "market_id": String(marketId)]
        switch self {
        case let value as PerpsPreparedTradingAction: fields.merge(value.intent.operationLogFields) { _, new in new }
        case is PerpsPreparedCloseAction: fields["action"] = "close"
        case let value as PerpsPreparedSizeChangeAction: fields.merge(value.intent.operationLogFields) { _, new in new }
        case let value as PerpsPreparedMarginChangeAction: fields.merge(value.intent.operationLogFields) { _, new in new }
        case let value as PerpsPreparedAutoCloseChangeAction: fields.merge(value.intent.operationLogFields) { _, new in new }
        case let value as PerpsPreparedLimitOrderChangeAction: fields.merge(value.intent.operationLogFields) { _, new in new }
        default: fields["action"] = "unknown"
        }
        return fields
    }
}

extension PerpsPendingTradingAction {
    var operationLogFields: [String: String] {
        var fields = ["flow": "trade", "trace_id": operationId, "operation_id": operationId, "wallet_id": walletId, "market_id": String(marketId), "side": side.rawValue]
        switch payload {
        case let .open(limitPrice):
            fields["action"] = "open"
            fields["order_type"] = limitPrice == nil ? "market" : "limit"
            fields["limit_price"] = limitPrice.map { String($0) }
        case .close: fields["action"] = "close"
        case let .sizeChange(change, _):
            fields["action"] = "size_change"
            fields["direction"] = change.direction.rawValue
        case let .marginChange(change):
            fields["action"] = "margin_change"
            fields["direction"] = change.direction.rawValue
        case .autoCloseChange: fields["action"] = "auto_close_change"
        case .limitOrderChange: fields["action"] = "limit_order_change"
        case .autoCloseRebase: fields["action"] = "auto_close_rebase"
        }
        fields["tx_hashes"] = signedSteps?.map(\.txHash).joined(separator: ",")
        fields["step_states"] = signedSteps?.map { "\($0.stepId):\($0.state.rawValue)" }.joined(separator: ",")
        fields["order_indices"] = orderRefs?.map { "\($0.role.rawValue):\($0.clientOrderIndex)" }.joined(separator: ",")
        fields["expected_base_size"] = expectedBaseSize.map { String($0) }
        fields["base_size_before"] = positionBaseSizeBefore.map { String($0) }
        return fields
    }
}
