import UIKit
import TKUIKit

final class StakingAmountInputView: UIView {
  var didUpdateText: ((String?) -> Void)?
  
  private let rootVStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = .spacing
    
    return stack
  }()
  
  private let containerHStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    
    return stack
  }()
  
  lazy var inputControl: TKTextInputTextFieldControl = {
    let textInputControl = TKTextInputTextFieldControl()
    textInputControl.keyboardAppearance = .dark
    textInputControl.keyboardType = .decimalPad
    return textInputControl
  }()
  
  lazy var textField: TKTextField = {
    return TKTextField(
      textFieldInputView: TKTextFieldInputView(
        textInputControl: inputControl
      )
    )
  }()
  
  let secondaryAmountView = StakingSecondaryAmountView()
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private methods

private extension StakingAmountInputView {
  func setup() {
    textField.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
    }
    
    layer.cornerRadius = .cornerRadius
    backgroundColor = .Background.content
    
    containerHStack.addSpacer()
    containerHStack.addArrangedSubview(secondaryAmountView)
    containerHStack.addSpacer()
    
    rootVStack.addArrangedSubview(textField)
    rootVStack.addArrangedSubview(containerHStack)
  
    rootVStack.layout(in: self) {
      $0.top.equalToSuperview().offset(CGFloat.topPadding)
      $0.trailing.equalToSuperview().inset(CGFloat.sidePadding)
      $0.leading.equalToSuperview().offset(CGFloat.sidePadding)
      $0.centerX.equalToSuperview()
      $0.height.greaterThanOrEqualTo(CGFloat.minHeight)
    }
    
    secondaryAmountView.snp.makeConstraints {
      $0.centerX.equalToSuperview()
    }
  }
}

private extension CGFloat {
  static let topPadding: Self = 39
  static let minHeight: Self = 100
  static let cornerRadius: Self = 16
  static let spacing: Self = 16
  static let sidePadding: Self = 8
}

extension UIStackView {
  func addSpacer() {
    addArrangedSubview(UIView())
  }
}
