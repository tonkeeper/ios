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
    okAction: @escaping () -> Void) -> InsufficientFundsViewController.Configuration {
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
      
      let caption = """
    To be paid: \(requiredFormattedAmount)
    Your balance: \(availableFormattedAmount)
    """
      
      var okButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
      okButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.ok))
      okButtonConfiguration.action = okAction
      
      return InsufficientFundsViewController.Configuration(
        caption: caption,
        buttons: [okButtonConfiguration]
      )
    }
}
