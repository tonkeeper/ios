import UIKit
import TKUIKit
import SnapKit

final class BrowserHeaderView: UIView {
  
  let backgroundView = TKBlurView()
  let segmentedControlView = BrowserSegmentedControl()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension BrowserHeaderView {
  func setup() {
    addSubview(backgroundView)
    backgroundView.addSubview(segmentedControlView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    segmentedControlView.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide).offset(8)
      make.left.equalTo(safeAreaLayoutGuide).offset(8)
      make.right.lessThanOrEqualTo(self).offset(-8)
      make.bottom.equalTo(self).offset(-8)
    }
  }
}
