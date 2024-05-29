import UIKit

public class TKPasswordTextField: TKTextField {
  
  private var passwordText = "" {
    didSet {
      didUpdateText?(passwordText)
    }
  }
  
  public init() {
    let textFieldControl = TKTextInputTextFieldControl()
    let inputView = TKTextFieldInputView(textInputControl: textFieldControl)
    super.init(textFieldInputView: inputView)
    inputView.clearButtonMode = .never
    textFieldControl.delegate = self
    textFieldControl.textAlignment = .center
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKPasswordTextField {
  func getHashPasswordString() -> NSAttributedString {
    let hashPassword = (0..<passwordText.count).map { _ in "\u{25CF}" }.joined()
    return getAttributedPasswordHashString(
      string: hashPassword,
      state: textFieldState
    )
  }
  
  func getAttributedPasswordHashString(string: String,
                                       state: TKTextFieldState) -> NSAttributedString {
    let color: UIColor
    switch state {
    case .active, .inactive:
      color = .Icon.secondary
    case .error:
      color = .Accent.red
    }
    return NSAttributedString(
      string: string,
      attributes: [
        .kern: 3,
        .foregroundColor: color,
        .font: TKTextStyle.h2.font
      ])
  }
}

extension TKPasswordTextField: UITextFieldDelegate {
  public func textField(_ textField: UITextField,
                        shouldChangeCharactersIn range: NSRange,
                        replacementString string: String) -> Bool {
    guard let stringRange = Range(range, in: passwordText) else {
      return false
    }
    let oldLength = passwordText.count
    passwordText.replaceSubrange(stringRange, with: string)
    let newLength = passwordText.count
    
    var newPosition: UITextPosition?
    if let selectedRange = textField.selectedTextRange {
      let lengthDiff = newLength - oldLength
      newPosition = textField.position(from: selectedRange.start, offset: lengthDiff)
    }

    textField.attributedText = getHashPasswordString()
    
    if let newPosition = newPosition {
      textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
    }
    return false
  }
}
