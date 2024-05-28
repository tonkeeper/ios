import UIKit
import TKUIKit

public class PlainTextField: UITextField {
  
  public enum TextFieldState {
    case inactive
    case active
    case error
    
    var textColor: UIColor {
      switch self {
      case .inactive:
        return .Text.tertiary
      case .active:
        return .Text.primary
      case .error:
        return .Accent.red
      }
    }
  }
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  
  public var textFieldState: TextFieldState = .inactive {
    didSet {
      didUpdateTextFieldState()
    }
  }
  
  public override var isEnabled: Bool {
    didSet {
      textFieldState = isEnabled ? .active : .inactive
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = .clear
    font = TKTextStyle.num2.font
    textColor = .Text.primary
    tintColor = .Accent.blue
    keyboardType = .decimalPad
    autocapitalizationType = .none
    autocorrectionType = .no
    keyboardAppearance = .dark
    
    addTarget(self, action: #selector(editingChanged), for: .editingChanged)
    addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
    addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)
  }
  
  @objc func editingChanged() {
    didUpdateText?(text ?? "")
  }
  
  @objc func editingDidBegin() {
    didBeginEditing?()
  }
  
  @objc func editingDidEnd() {
    didEndEditing?()
  }
  
  private func didUpdateTextFieldState() {
    if isEnabled {
      textColor = textFieldState.textColor
    } else {
      textColor = TextFieldState.inactive.textColor
    }
  }
}
