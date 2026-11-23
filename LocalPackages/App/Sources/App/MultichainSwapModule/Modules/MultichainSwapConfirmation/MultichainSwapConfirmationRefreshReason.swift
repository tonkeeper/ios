enum MultichainSwapConfirmationRefreshReason: Equatable {
    case initial
    case timer
    case slippageChanged
    case feeDeposit
    case executionFailed
    case retry
    /// A Swap tap that found no plan on its way.
    case swapTap

    /// A deposit changes what can pay the fee, so a route prepared before it is prepared again. So is the route
    /// a Swap tap asks for: what it was last prepared to, such as a shortage kept for it, brought no plan.
    var reusesPreparedPlan: Bool {
        switch self {
        case .feeDeposit, .swapTap:
            return false
        case .initial, .timer, .slippageChanged, .executionFailed, .retry:
            return true
        }
    }

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
        case .swapTap:
            return "swap_tap"
        }
    }
}
