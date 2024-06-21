import Foundation

enum TotalBalanceState: Equatable {
  case current(TotalBalance)
  case previous(TotalBalance)
  
  var totalBalance: TotalBalance {
    switch self {
    case .current(let totalBalance):
      return totalBalance
    case .previous(let totalBalance):
      return totalBalance
    }
  }
}
