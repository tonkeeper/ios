import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import BigInt

struct InfoPopupBottomSheetConfigurationBuilder {
  
  private let amountFormatter: AmountFormatter
  
  init(amountFormatter: AmountFormatter) {
    self.amountFormatter = amountFormatter
  }
  
  func insufficientTokenConfiguration(
    walletLabel: String?,
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

      let title: String
      if let walletLabel {
        title = TKLocales.InsufficientFunds.Wallet.title(walletLabel)
      } else {
        title = TKLocales.InsufficientFunds.title
      }

      let attributedTitle = title.withTextStyle(
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
//        .withTextStyle(
//        .body1,
//        color: .Text.secondary,
//        alignment: .center
//      )

      return InsufficientFundsViewController.Configuration(
        title: attributedTitle,
        caption: caption,
        buttons: buttons
      )
    }

  func commonConfiguration(
    title: String,
    caption: String,
    body: [InfoPopupBottomSheetViewController.Configuration.BodyView]? = nil,
    buttons: [TKButton.Configuration]
  ) -> InfoPopupBottomSheetViewController.Configuration {
    InfoPopupBottomSheetViewController.Configuration(
      image: nil,
      imageTintColor: nil,
      title: title,
      caption: caption,
      bodyContent: body,
      buttons: buttons
    )
  }
}

