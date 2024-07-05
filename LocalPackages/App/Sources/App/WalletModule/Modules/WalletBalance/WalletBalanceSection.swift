import Foundation
import TKUIKit
import KeeperCore

enum WalletBalanceSection: Hashable {
  case balance
  case setup(TKListTitleView.Model)
  case manage
  case notifications
}

struct WalletBalanceSetupSection: Hashable {
  let title: String
  let isFinishEnable: Bool
}

enum WalletBalanceItem: Hashable {
  case notificationItem(String)
  case balanceItem(String)
  case manageButton(WalletsListAddWalletCell.Model)
}

enum WalletBalanceSetupItem: String, Hashable {
  case biometry
  case telegramChannel
  case backup
}
