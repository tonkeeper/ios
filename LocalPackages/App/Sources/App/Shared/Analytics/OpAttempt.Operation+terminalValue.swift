import TKCore

extension OpAttempt.Operation {
    var opTerminalValue: OpTerminal.Operation {
        switch self {
        case .emulate:
            return .emulate
        case .send:
            return .send
        case .quote:
            return .quote
        case .stake:
            return .stake
        case .unstake:
            return .unstake
        case .connectWallet:
            return .connectWallet
        case .confirmTransaction:
            return .confirmTransaction
        }
    }
}
