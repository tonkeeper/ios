import TKLocalize

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

    var statusLine: String? {
        switch self {
        case .idle:
            return nil
        case .executing:
            return TKLocales.Toast.loading
        case .completed:
            return TKLocales.Result.success
        case .preparationFailed, .executionFailed:
            return TKLocales.State.failed
        }
    }

    var confirmTitle: String {
        switch self {
        case .idle, .preparationFailed:
            return TKLocales.Actions.Confirm.title
        case .executionFailed:
            return TKLocales.Actions.retry
        case .executing:
            return TKLocales.ActionTypes.Future.swap
        case .completed:
            return TKLocales.Result.success
        }
    }

    var confirmSubtitle: String {
        switch self {
        case .idle, .preparationFailed, .executionFailed:
            return TKLocales.Actions.Confirm.subtitle
        case .executing:
            return TKLocales.Toast.loading
        case .completed:
            return ""
        }
    }
}
