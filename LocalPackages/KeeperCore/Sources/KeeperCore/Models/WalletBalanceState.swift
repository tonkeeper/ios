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

    func needsListRefresh(at date: Date = Date(), freshnessInterval: TimeInterval) -> Bool {
        guard case let .current(balance) = self else {
            return true
        }
        return date.timeIntervalSince(balance.date) >= freshnessInterval
    }
}
