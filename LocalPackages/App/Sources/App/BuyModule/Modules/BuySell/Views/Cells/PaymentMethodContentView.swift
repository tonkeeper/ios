import UIKit
import TKUIKit

final class PaymentMethodContentView: UIView, ConfigurableView, ReusableView {
  let titleLabel = UILabel()
  let paymentIconView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func prepareForReuse() {
    titleLabel.attributedText = nil
    paymentIconView.image = nil
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    titleLabel.tkSizeThatFits(size.width)
  }
  
  struct Model: Hashable {
    let title: NSAttributedString
    let paymentIcon: UIImage
    
    init(title: NSAttributedString, paymentIcon: UIImage) {
      self.title = title
      self.paymentIcon = paymentIcon
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    paymentIconView.image = model.paymentIcon
  }
}

private extension PaymentMethodContentView {
  func setup() {
    addSubview(titleLabel)
    addSubview(paymentIconView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleLabel.snp.makeConstraints { make in
      make.left.equalTo(self).offset(CGFloat.horizontalPadding)
      make.centerY.equalTo(self)
    }
    
    paymentIconView.snp.makeConstraints { make in
      make.right.centerY.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let horizontalPadding: CGFloat = 16
}
