import UIKit
import TKUIKit

final class WalletBalanceView: UIView {
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension WalletBalanceView {
  func setup() {
    backgroundColor = .Background.page
  }
}
