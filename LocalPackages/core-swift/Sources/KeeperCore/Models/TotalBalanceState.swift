import Foundation

public enum TotalBalanceState {
    case current(TotalBalance)
    case previous(TotalBalance)
    case none

    public var totalBalance: TotalBalance? {
        switch self {
        case let .current(totalBalance):
            return totalBalance
        case let .previous(totalBalance):
            return totalBalance
        case .none:
            return nil
        }
    }
}
