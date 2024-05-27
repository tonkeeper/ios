import UIKit
import SnapKit
import TKUIKit

final class SwapConfirmationView: UIView {

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
    setupConstraints()
  }
}

private extension SwapConfirmationView {
  func setup() {
    backgroundColor = .cyan
//    addSubview(contentContainer)
//    contentContainer.backgroundColor = .red
  }

  func setupConstraints() {
//    contentContainer.snp.makeConstraints { make in
//      make.top.equalTo(self)
//      make.left.bottom.right.equalTo(self).priority(.high)
//    }
  }
}
