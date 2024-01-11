import UIKit
import TKUIKit

final class CollectiblesView: UIView {
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension CollectiblesView {
  func setup() {
    backgroundColor = .Background.page
  }
}
