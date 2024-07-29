import Foundation

public enum TotalBalanceState: Equatable {
  case current(TotalBalance)
  case previous(TotalBalance)
  case none
  
  public var totalBalance: TotalBalance? {
    switch self {
    case .current(let totalBalance):
      return totalBalance
    case .previous(let totalBalance):
      return totalBalance
    case .none:
      return nil
    }
  }
}
