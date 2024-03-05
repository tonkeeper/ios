import UIKit
import TKUIKit

final class SendRoundedBackgroundView: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = 16
  }
}
