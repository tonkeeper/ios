import Foundation
import KeeperCore

struct BalanceBackupWarningCheck {
  enum State {
    case error
    case warning
    case none
  }
  
  func check(wallet: Wallet, tonAmount: UInt64) -> State {
    guard wallet.isBackupAvailable else { return .none }
    guard !wallet.hasBackup else { return .none }
    switch tonAmount {
    case _ where tonAmount >= .tonAmountError:
      return .error
    case _ where tonAmount >= .tonAmountWarning:
      return .warning
    default:
      return .none
    }
  }
}

private extension UInt64 {
  static let tonAmountWarning: UInt64 = 2_000_000_000
  static let tonAmountError: UInt64 = 20_000_000_000
}
