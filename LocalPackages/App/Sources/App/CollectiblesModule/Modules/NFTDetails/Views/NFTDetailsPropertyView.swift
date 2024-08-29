import UIKit
import TKUIKit

final class NFTDetailsPropertyView: UIView, ConfigurableView {
  struct Model {
    let title: String
    let value: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .left
    )
    valueLabel.attributedText = model.value.withTextStyle(
      .body1,
      color: .Text.primary,
      alignment: .left
    )
  }
  
  private let titleLabel = UILabel()
  private let valueLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = .cornerRadius
    layer.masksToBounds = true
    
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(valueLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.left.right.equalTo(self).inset(CGFloat.sideSpace)
      make.top.equalTo(self).offset(CGFloat.topSpace)
      make.bottom.equalTo(self).offset(-CGFloat.bottomSpace)
    }
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let sideSpace: CGFloat = 16
  static let topSpace: CGFloat = 10
  static let bottomSpace: CGFloat = 12
}
