import UIKit
import TKUIKit
import SnapKit

final class ListDescriptionContainerView: UIView, ConfigurableView {
  
  let descriptionLabel = UILabel()
  let valueLabel = UILabel()
  
  override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var height = descriptionLabel.sizeThatFits(size).height
    height += .topPadding
    height += .bottomPadding
    return CGSize(width: bounds.width, height: height)
  }
  
  struct Model {
    var description: NSAttributedString
    var value: NSAttributedString?
    
    init(description: NSAttributedString, value: NSAttributedString? = nil) {
      self.description = description
      self.value = value
    }
  }
  
  func configure(model: Model) {
    descriptionLabel.attributedText = model.description
    valueLabel.attributedText = model.value
    valueLabel.isHidden = model.value == nil
    
    invalidateIntrinsicContentSize()
  }
}

private extension ListDescriptionContainerView {
  func setup() {
    addSubview(descriptionLabel)
    addSubview(valueLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    descriptionLabel.snp.makeConstraints { make in
      make.left.equalTo(self).offset(CGFloat.horizontalPadding)
      make.top.equalTo(CGFloat.topPadding)
    }
    
    valueLabel.snp.makeConstraints { make in
      make.right.equalTo(self).inset(CGFloat.horizontalPadding)
      make.top.equalTo(CGFloat.topPadding)
    }
  }
}

private extension CGFloat {
  static let topPadding: CGFloat = 12
  static let bottomPadding: CGFloat = 16
  static let horizontalPadding: CGFloat = 16
}
