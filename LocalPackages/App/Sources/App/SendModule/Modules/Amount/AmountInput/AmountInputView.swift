import UIKit
import TKUIKit
import SnapKit

final class AmountInputView: UIView {
  let inputControl = AmountInputViewInputControl()
  
  let convertedButton: TKButton = {
    let button = TKButton()
    button.layer.masksToBounds = true
    button.layer.borderWidth = .convertedButtonBorderWidth
    button.layer.borderColor = UIColor.Button.tertiaryBackground.cgColor
    return button
  }()
  
  private let container = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension AmountInputView {
  func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    
    addSubview(container)
    container.addSubview(inputControl)
    container.addSubview(convertedButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    container.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.centerY.equalTo(self)
    }
    
    inputControl.snp.makeConstraints { make in
      make.top.equalTo(container)
      make.left.right.equalTo(container)
    }
    
    convertedButton.snp.makeConstraints { make in
      make.top.equalTo(inputControl.snp.bottom).offset(CGFloat.convertedButtonTopSpace)
      make.left.greaterThanOrEqualTo(container).offset(16)
      make.right.lessThanOrEqualTo(container).offset(-16)
      make.bottom.equalTo(container)
      make.centerX.equalTo(container)
    }
  }
}

private extension CGFloat {
  static let inputContainerSideSpacing: CGFloat = 40
  static let convertedButtonTopSpace: CGFloat = 10
  static let convertedButtonBorderWidth: CGFloat = 1.5
}
