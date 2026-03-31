import Foundation

public enum WalletBalanceState: Equatable {
    case current(WalletBalance)
    case previous(WalletBalance)

    public var walletBalance: WalletBalance {
        switch self {
        case let .current(walletBalance):
            return walletBalance
        case let .previous(walletBalance):
            return walletBalance
        }
    }
}
