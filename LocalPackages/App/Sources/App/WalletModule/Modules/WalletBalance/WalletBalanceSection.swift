import Foundation
import TKUIKit
import KeeperCore

enum WalletBalanceSection: Hashable {
  case balance
  case setup(TKListTitleView.Model)
}

struct WalletBalanceSetupSection: Hashable {
  let title: String
  let isFinishEnable: Bool
}

struct WalletBalanceItem: Hashable {
  let id: String
}

enum WalletBalanceSetupItem: String, Hashable {
  case biometry
  case telegramChannel
  case backup
}
