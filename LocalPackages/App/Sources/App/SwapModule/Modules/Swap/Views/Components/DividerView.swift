import UIKit
import TKUIKit
import SnapKit

final class DividerView: UIView {
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    guard let superview else { return }
    self.snp.remakeConstraints { make in
      make.left.right.top.equalTo(superview)
      make.height.equalTo(Constants.separatorWidth)
    }
  }
  
  static func createDivider() -> DividerView {
    let view = DividerView()
    view.backgroundColor = .Separator.common
    return view
  }
}

extension UIView {
  static func topDivider() -> UIView {
    DividerView.createDivider()
  }
}
