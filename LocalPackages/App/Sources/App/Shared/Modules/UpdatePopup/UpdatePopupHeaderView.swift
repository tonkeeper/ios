import UIKit
import TKUIKit

final class UpdatePopupHeaderView: TKView {
  
  var image: UIImage? {
    didSet {
      imageView.image = image
    }
  }
  
  private let imageView = UIImageView()
  
  override func setup() {
    imageView.layer.cornerRadius = 24
    imageView.layer.masksToBounds = true
    imageView.layer.cornerCurve = .continuous
    imageView.layer.borderColor = UIColor.Separator.common.cgColor
    imageView.layer.borderWidth = 1
    
    addSubview(imageView)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    imageView.snp.makeConstraints { make in
      make.width.height.equalTo(96)
      make.top.bottom.equalTo(self).inset(16)
      make.centerX.equalTo(self)
    }
  }
}
