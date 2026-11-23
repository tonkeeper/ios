enum MultichainSwapConfirmationExecutionState: Equatable {
    case idle
    case executing
    case completed
    case preparationFailed(String)
    case executionFailed(String)
}

extension MultichainSwapConfirmationExecutionState {
    var isConfirmEnabled: Bool {
        switch self {
        case .idle, .preparationFailed, .executionFailed:
            return true
        case .executing, .completed:
            return false
        }
    }
}
