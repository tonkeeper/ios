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
//    ""
//    let maximumFractionDigits = 2
//    
//    let amount: BigUInt
//    let fractionDigits: Int
//    
//    if let balance = totalBalanceState?.totalBalance {
//      amount = balance.amount
//      fractionDigits = balance.fractionalDigits
//    } else {
//      amount = 0
//      fractionDigits = 0
//    }
//    
//    return amountFormatter.formatAmountWithoutFractionIfThousand(
//      amount,
//      fractionDigits: fractionDigits,
//      maximumFractionDigits: maximumFractionDigits,
//      currency: currency
//    )
  }
}
