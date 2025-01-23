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
    caption: String? = nil,
    tokenSymbol: String,
    tokenFractionalDigits: Int,
    required: BigUInt,
    available: BigUInt,
    buttons: [TKButton.Configuration]
  ) -> InfoPopupBottomSheetViewController.Configuration {

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

    let resultCaption = caption ?? TKLocales.InsufficientFunds.toBePaidYourBalance(
      requiredFormattedAmount, availableFormattedAmount
    )

    return .init(
      image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
      imageTintColor: .Icon.secondary,
      title: title,
      caption: resultCaption,
      bodyContent: nil,
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

