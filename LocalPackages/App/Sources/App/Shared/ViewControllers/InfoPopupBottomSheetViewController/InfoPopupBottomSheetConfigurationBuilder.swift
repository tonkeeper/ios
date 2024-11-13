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
    tokenSymbol: String,
    tokenFractionalDigits: Int,
    required: BigUInt,
    available: BigUInt,
    okAction: @escaping () -> Void) -> InfoPopupBottomSheetViewController.Configuration {
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

      let title = "Insufficient Funds"
      let caption = """
    To be paid: \(requiredFormattedAmount)
    Your balance: \(availableFormattedAmount)
    """
      
      var okButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
      okButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.ok))
      okButtonConfiguration.action = okAction

      return InfoPopupBottomSheetViewController.Configuration(
        image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
        imageTintColor: .Icon.secondary,
        title: title,
        caption: caption,
        bodyContent: nil,
        buttons: [okButtonConfiguration]
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
