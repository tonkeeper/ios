import UIKit
import TKUIKit
import SnapKit

final class SendConfirmationView: UIView {
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SendConfirmationView {
  func setup() {
    backgroundColor = .Background.page
  }
  
  func setupConstraints() {
    
  }
}
