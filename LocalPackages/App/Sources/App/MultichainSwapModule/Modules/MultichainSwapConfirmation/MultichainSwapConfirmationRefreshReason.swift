enum MultichainSwapConfirmationRefreshReason: Equatable {
    case initial
    case timer
    case slippageChanged
    case feeDeposit
    case executionFailed

    /// Automatic refreshes (`.timer`, and the one that follows a failed swap) update state
    /// silently; user-initiated refreshes (initial load, slippage change, fee deposit) surface a
    /// toast. Keeps the background quote loop from re-alerting the same error every cycle, and
    /// keeps a recovery refresh from toasting on top of the failure the user already saw.
    var surfacesUserFacingError: Bool {
        switch self {
        case .initial, .slippageChanged, .feeDeposit:
            return true
        case .timer, .executionFailed:
            return false
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
        }
    }
}
