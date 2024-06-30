import Foundation
import KeeperCore

//enum WalletBalanceSection: Hashable {
//  case balance(items: [WalletBalanceBalanceItem])
//  case setup(items: [WalletBalanceSetupItem])
//}

struct WalletBalanceSection: Identifiable {
  enum Identifier: String {
    case balance
    case setup
  }
  
  let id: Identifier
  let items: [AnyHashable]
}

struct WalletBalanceBalanceItem: Hashable {
  let id: String
}

enum WalletBalanceSetupItem: Hashable {
  case notifications
  case biometry
  case tonkeeperChannel
  case backup
}
