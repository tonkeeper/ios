import UIKit
import TKUIKit

final class NFTDetailsSectionHeaderView: UIView, ConfigurableView {
  
  struct Model {
    let title: String
    let buttonModel: TKPlainButton.Model?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .h3,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    if let buttonModel = model.buttonModel {
      button.isHidden = false
      button.configure(model: buttonModel)
    } else {
      button.isHidden = true
    }
  }
  
  private let titleLabel = UILabel()
  private let button = TKPlainButton()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
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
    button.setContentHuggingPriority(.required, for: .horizontal)
    
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(button)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
      make.left.right.equalTo(self).inset(2)
      make.height.equalTo(56)
    }
  }
}
