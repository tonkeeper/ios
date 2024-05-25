import UIKit
import TKUIKit
import SnapKit

final class SendV3AmountInputView: UIView {
  
  var didUpdateText: ((String?) -> Void)?
  var didTapTokenPicker: (() -> Void)?
  
  lazy var textInputControl: TKTextInputTextFieldControl = {
    let textInputControl = TKTextInputTextFieldControl()
    textInputControl.keyboardType = .decimalPad
    return textInputControl
  }()
  
  lazy var amountTextField: TKTextField = {
    return TKTextField(
      textFieldInputView: TKTextFieldInputView(
        textInputControl: textInputControl
      )
    )
  }()
  
  let balanceView = SendV3AmountBalanceView()
  let tokenView = SendV3AmountInputTokenView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    amountTextField.rightItems = [TKTextField.RightItem(view: tokenView, mode: .always)]
    
    addSubview(amountTextField)
    addSubview(balanceView)
    
    amountTextField.snp.makeConstraints { make in
      make.left.top.right.equalTo(self)
    }
    
    balanceView.snp.makeConstraints { make in
      make.top.equalTo(amountTextField.snp.bottom)
      make.left.bottom.right.equalTo(self)
    }
    
    amountTextField.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
    }
    
    tokenView.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapTokenPicker?()
    }), for: .touchUpInside)
  }
}
