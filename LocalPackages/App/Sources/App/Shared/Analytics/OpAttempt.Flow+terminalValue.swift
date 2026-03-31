import TKCore

extension OpAttempt.Flow {
    var opTerminalValue: OpTerminal.Flow {
        switch self {
        case .transfer:
            return .transfer
        case .swap:
            return .swap
        case .stake:
            return .stake
        case .tonConnect:
            return .tonConnect
        }
    }
}
