import Foundation
import BigInt

struct WalletListMapper {
  
  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let rateConverter: RateConverter
  
  init(amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter,
       rateConverter: RateConverter) {
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
    self.rateConverter = rateConverter
  }
  
  func mapWalletModel(wallet: Wallet,
                      balance: String) -> WalletListController.ItemModel {
    let walletModel = wallet.model
    return WalletListController.ItemModel(
      id: walletModel.identifier,
      walletModel: walletModel,
      totalBalance: balance
    )
  }
  
  func mapTotalBalance(_ totalBalance: TotalBalance,
                       currency: Currency) -> String {
    amountFormatter.formatAmountWithoutFractionIfThousand(
      totalBalance.amount,
      fractionDigits: totalBalance.fractionalDigits,
      maximumFractionDigits: 2,
      currency: currency
    )
  }
}
