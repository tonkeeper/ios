import UIKit
import TKUIKit

final class WalletsListDecorationBackgroundView: UICollectionReusableView, ReusableView {
  private let colorView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    colorView.backgroundColor = .Background.content
    addSubview(colorView)
    
    colorView.layer.cornerRadius = 16
    colorView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
      make.left.right.equalTo(self).inset(16)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
