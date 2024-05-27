import UIKit
import SnapKit
import TKUIKit

final class SwapConfirmationView: UIView {

  let scrollView = TKUIScrollView()

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

}

private extension SwapConfirmationView {
  func setup() {
    addSubview(scrollView)
    setupConstraints()
  }

  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
  }
}
