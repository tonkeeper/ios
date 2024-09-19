import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct WalletBalanceHeaderMapper {
  
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let dateFormatter: DateFormatter
  
  init(decimalAmountFormatter: DecimalAmountFormatter,
       dateFormatter: DateFormatter) {
    self.decimalAmountFormatter = decimalAmountFormatter
    self.dateFormatter = dateFormatter
  }
  
  func makeUpdatedDate(_ date: Date) -> String {
    dateFormatter.dateFormat = "MMM d, HH:mm"
    return dateFormatter.string(from: date)
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
