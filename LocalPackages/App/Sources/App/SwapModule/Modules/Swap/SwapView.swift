import UIKit
import SnapKit
import TKUIKit

final class SwapView: UIView {

  let scrollView = TKUIScrollView()
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .contentVerticalPadding
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return stackView
  }()

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .red
    setup()
  }

}

private extension SwapView {
  func setup() { }
}

extension SwapView {
  struct Model { }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
}
