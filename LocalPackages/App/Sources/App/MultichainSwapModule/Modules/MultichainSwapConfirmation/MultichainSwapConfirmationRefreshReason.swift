enum MultichainSwapConfirmationRefreshReason: Equatable {
    case initial
    case timer
    case slippageChanged
    case feeDeposit
    case executionFailed
    case retry

    var logValue: String {
        switch self {
        case .initial:
            return "initial"
        case .timer:
            return "timer"
        case .slippageChanged:
            return "slippage_changed"
        case .feeDeposit:
            return "fee_deposit"
        case .executionFailed:
            return "execution_failed"
        case .retry:
            return "retry"
        }
    }
}
