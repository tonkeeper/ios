import UIKit

class TKButtonPaddingLabel: UILabel {

  var insets = UIEdgeInsets.zero

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: insets))
  }
}
