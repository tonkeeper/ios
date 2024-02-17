import Foundation
import TKUIKit

enum WalletBalanceSection: Hashable {
  case balanceItems
  case finishSetup
  
  var title: String? {
    switch self {
    case .balanceItems:
      return nil
    case .finishSetup:
      return "Finish setting up"
    }
  }
}
