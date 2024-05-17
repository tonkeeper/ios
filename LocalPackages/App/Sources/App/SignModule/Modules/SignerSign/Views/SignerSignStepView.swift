import UIKit
import TKUIKit

final class SignerSignStepView: UIView, ConfigurableView {
  let containerView = UIView()
  let contentView = TKUIListItemView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let contentModel: TKUIListItemView.Configuration
    let isFirst: Bool
    let isLast: Bool
  }
  
  func configure(model: Model) {
    contentView.configure(configuration: model.contentModel)
    setupCornerRadius(isFirst: model.isFirst, isLast: model.isLast)
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
}

private extension SignerSignStepView {
  func setup() {
    containerView.backgroundColor = .Background.content
    containerView.layer.cornerRadius = 16
    
    addSubview(containerView)
    containerView.addSubview(contentView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(containerView).inset(16)
    }
  }
  
  func setupCornerRadius(isFirst: Bool, isLast: Bool) {
    let maskedCorners: CACornerMask
    let isMasksToBounds: Bool
    switch (isFirst, isLast) {
    case (true, true):
      maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      isMasksToBounds = true
    case (false, true):
      maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      isMasksToBounds = true
    case (true, false):
      maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      isMasksToBounds = true
    case (false, false):
      maskedCorners = []
      isMasksToBounds = false
    }
    containerView.layer.maskedCorners = maskedCorners
    containerView.layer.masksToBounds = isMasksToBounds
  }
}
