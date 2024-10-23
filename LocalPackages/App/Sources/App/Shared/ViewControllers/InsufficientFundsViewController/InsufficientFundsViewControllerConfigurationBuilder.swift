import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import BigInt

struct InsufficientFundsViewControllerConfigurationBuilder {
  
  private let amountFormatter: AmountFormatter
  
  init(amountFormatter: AmountFormatter) {
    self.amountFormatter = amountFormatter
  }
  
  func insufficientTokenConfiguration(
    tokenSymbol: String,
    tokenFractionalDigits: Int,
    required: BigUInt,
    available: BigUInt,
    buttons: [TKButton.Configuration]) -> InsufficientFundsViewController.Configuration {
      let requiredFormattedAmount = amountFormatter.formatAmount(
        required,
        fractionDigits: tokenFractionalDigits,
        maximumFractionDigits: 2,
        symbol: tokenSymbol
      )
      
      let availableFormattedAmount = amountFormatter.formatAmount(
        available,
        fractionDigits: tokenFractionalDigits,
        maximumFractionDigits: 2,
        symbol: tokenSymbol
      )

      let title = TKLocales.InsufficientFunds.title
        .withTextStyle(
          .h2,
          color: .Text.primary,
          alignment: .center
        )

      let caption = TKLocales.InsufficientFunds.toBePaidYourBalance(
        requiredFormattedAmount, availableFormattedAmount
      ).withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .center
      )

      return InsufficientFundsViewController.Configuration(
        title: title,
        caption: caption,
        buttons: buttons
      )
    }
}

