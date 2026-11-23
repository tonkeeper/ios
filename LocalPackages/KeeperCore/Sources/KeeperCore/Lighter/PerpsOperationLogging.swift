import Foundation
import OpenAPIRuntime
import TKLogging

extension PerpsAPIError: PerpsOperationLoggableError {
    var operationLogFields: [String: String] {
        guard case let .badStatus(failure) = self else { return [:] }
        var fields = ["http_status": String(failure.httpStatus), "retryable": String(failure.retryable)]
        fields["code"] = failure.code
        fields["reason"] = failure.reason
        fields["detail"] = failure.detail
        fields["min_usd_amount"] = failure.minUsdAmount
        return fields
    }

    var operationLogSource: String {
        switch self {
        case let .badStatus(failure):
            return switch failure.reason {
            case "lighter_rejected": "lighter"
            case "resign_required", "invalid_transaction", "malformed_tx_info", "foreign_account": "client"
            case "integrator_not_approved": "wallet"
            case "amount_too_low", "insufficient_balance", "insufficient_funds", "no_lighter_account": "wallet"
            default: "backend"
            }
        case let .transport(underlying):
            let underlying = (underlying as? ClientError)?.underlyingError ?? underlying
            if let urlError = underlying as? URLError {
                return urlError.code == .cancelled ? "user_or_lifecycle" : "network"
            }
            return "unknown"
        case .badUrl: return "client"
        case .unauthorized, .notFound, .conflict, .badResponse: return "backend"
        case .unknown: return "unknown"
        }
    }
}

extension ChainKitOperationError: PerpsOperationLoggableError {
    var operationLogSource: String {
        switch self {
        case .unsupportedAccount, .keyMismatch, .insufficientFunds: "wallet"
        case .broadcastFailed, .feeUnavailable, .nonceUnavailable: "chain_rpc"
        case .malformed: "backend_or_client_contract"
        case .quoteExpired, .staleAuthorization, .signingFailed: "client"
        }
    }
}

extension PerpsFundingDeliveryError: PerpsOperationLoggableError {
    var operationLogSource: String {
        "wallet"
    }
}

extension PerpsPendingFundingOperation {
    var operationLogFields: [String: String] {
        var fields = ["operation_id": operationId, "wallet_id": walletId, "environment": environment, "revision": String(revision)]
        if let deposit {
            fields["flow"] = "deposit"
            fields["asset_id"] = deposit.sourceAsset.assetId
            fields["amount_units"] = deposit.sourceAmountUnits
            fields["operation_stage"] = deposit.stage.rawValue
            fields["quote_id"] = deposit.quoteId
            fields["execution_id"] = deposit.executionId
            fields["deposit_id"] = deposit.depositId
            fields["failure_reason"] = deposit.failureReason
            fields["chain"] = deposit.sourceAsset.assetId.split(separator: "/").first.map(String.init)
            fields["tx_hashes"] = deposit.transmission?.steps.compactMap(\.hash).joined(separator: ",")
            fields["broadcast_attempted"] = deposit.transmission.map { String($0.steps.contains(where: \.broadcastAttempted)) }
        } else if let withdraw {
            fields["flow"] = "withdraw"
            fields["asset_id"] = withdraw.destinationAssetId
            fields["chain"] = withdraw.destinationAssetId?.split(separator: "/").first.map(String.init)
            fields["amount_units"] = withdraw.amountUnits
            fields["operation_stage"] = withdraw.stage.rawValue
            fields["quote_id"] = withdraw.quoteId
            fields["execution_id"] = withdraw.executionId
            fields["account_index"] = String(withdraw.accountIndex)
            fields["l2_tx_hash"] = withdraw.steps.last?.txHash
            fields["l1_tx_hash"] = withdraw.l1TxHash
            fields["failure_reason"] = withdraw.failureReason
        }
        return fields
    }
}

extension PerpsDepositQuoteError: LoggableError, PerpsOperationLoggableError {
    var logDescription: String {
        String(describing: self)
    }

    var operationLogSource: String {
        switch self {
        case let .malformedKeyRegistration(reason) where reason == "trading key unavailable": "wallet"
        case .expired: "client"
        default: "backend_or_client_contract"
        }
    }
}

extension PerpsDepositServiceError: LoggableError, PerpsOperationLoggableError {
    var logDescription: String {
        String(describing: self)
    }

    var operationLogSource: String {
        switch self {
        case .insufficientNetworkFee: "wallet"
        case .networkFeeUnavailable: "chain_rpc"
        case .accountCreationPending, .registrationRejected: "backend"
        default: "client"
        }
    }
}

extension PerpsWithdrawServiceError: PerpsOperationLoggableError {
    public var operationLogSource: String {
        switch self {
        case .insufficientBalance, .belowMinimum: "wallet"
        case .accountUnavailable: "wallet_or_backend"
        case .feeChanged, .sendRefused: "lighter"
        case .sendUnknown, .nonceRefused: "unknown"
        case .paymentInFlight, .quoteExpired: "client"
        case .noRelayAccount: "config"
        }
    }
}

extension PerpsDepositRegistrationError: LoggableError, PerpsOperationLoggableError {
    var logDescription: String {
        String(describing: self)
    }

    var operationLogSource: String {
        switch self {
        case .missingDepositId, .mismatchedDeposit: "backend_or_client_contract"
        default: "client"
        }
    }
}

extension PerpsWithdrawQuoteError: LoggableError, PerpsOperationLoggableError {
    public var logDescription: String {
        String(describing: self)
    }

    public var operationLogSource: String {
        "backend_or_client_contract"
    }
}

extension PerpsPendingJournalError: LoggableError, PerpsOperationLoggableError {
    var logDescription: String {
        String(describing: self)
    }

    var operationLogSource: String {
        "client"
    }
}

extension PerpsFundingAmountError: LoggableError, PerpsOperationLoggableError {
    var logDescription: String {
        String(describing: self)
    }

    var operationLogSource: String {
        "client"
    }
}
