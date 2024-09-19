import Foundation

public enum WalletBalanceState: Equatable {
  case current(WalletBalance)
  case previous(WalletBalance)
  
  public var walletBalance: WalletBalance {
    switch self {
    case .current(let walletBalance):
      return walletBalance
    case .previous(let walletBalance):
      return walletBalance
    }
  }
}
