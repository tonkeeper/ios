import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct WalletBalanceHeaderMapper {
  
  private let decimalAmountFormatter: DecimalAmountFormatter
  
  init(decimalAmountFormatter: DecimalAmountFormatter) {
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  func mapTotalBalance(totalBalance: TotalBalance?) -> String {
    if let totalBalance = totalBalance {
      return decimalAmountFormatter.format(amount: totalBalance.amount,
                                           maximumFractionDigits: 2,
                                           currency: totalBalance.currency)
    } else {
      return "-"
    }
  }
}
