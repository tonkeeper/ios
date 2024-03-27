import UIKit
import TKUIKit

final class WalletBalanceSetupContentView: UIView, ConfigurableView, ReusableView {
  let titleLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func prepareForReuse() {
    titleLabel.attributedText = nil
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    titleLabel.frame = bounds
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    titleLabel.tkSizeThatFits(size.width)
  }
  
  struct Model {
    let title: NSAttributedString
    
    init(title: String) {
      self.title = title.withTextStyle(
        .body2,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
  }
}

private extension WalletBalanceSetupContentView {
  func setup() {
    titleLabel.numberOfLines = 0
    addSubview(titleLabel)
  }
}
