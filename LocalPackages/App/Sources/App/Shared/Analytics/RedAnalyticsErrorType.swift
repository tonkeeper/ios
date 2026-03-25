public enum RedAnalyticsErrorType: String {
    case feeCalculationFailed = "fee_calculation_failed"
    case incorrectWalletKind = "incorrect_wallet_kind"
    case insufficientFunds = "insufficient_funds"
    case nativeSwap = "native_swap"
    case network
    case signFailed = "sign_failed"
    case signRequestFailed = "sign_request_failed"
    case transactionSendFailed = "transaction_send_failed"
    case transferFailed = "transfer_failed"
    case walletTransferFailed = "wallet_transfer_failed"
    case connection
    case tonConnectSessionInterrupted = "ton_connect_session_interrupted"
    case signRequired = "sign_required"
}
