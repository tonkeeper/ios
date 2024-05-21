import UIKit
import TKUIKit

final class SwapAmountInputView: UIView, ConfigurableView {
  
  let tokenButton = SwapTokenButton()
  let textField = PlainTextField()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let tokenButtonFrame = CGRect(origin: .zero, size: tokenButton.sizeThatFits(bounds.size))
    
    let textFieldX = tokenButton.frame.maxX + .horizontalSpacing
    let textFieldWidth = bounds.width - tokenButton.frame.maxX - .horizontalSpacing
    let textFieldFrame = CGRect(
      x: textFieldX,
      y: 0,
      width: textFieldWidth,
      height: .itemHeight
    )
    
    tokenButton.frame = tokenButtonFrame
    textField.frame = textFieldFrame
  }
  
  struct Model {
    typealias Icon = SwapTokenButton.Model.Icon
    
    struct TokenButton {
      let title: String
      let icon: Icon
      let action: (() -> Void)?
    }
    
    let tokenButton: TokenButton
    let isInputEnabled: Bool
  }
  
  func configure(model: Model) {
    tokenButton.configure(
      model: SwapTokenButtonContentView.Model(
        title: model.tokenButton.title.withTextStyle(.label1, color: .Button.tertiaryForeground),
        icon: model.tokenButton.icon
      )
    )
    
    tokenButton.addTapAction {
      model.tokenButton.action?()
    }
    
    textField.isEnabled = model.isInputEnabled
    
    setNeedsLayout()
  }
}

private extension SwapAmountInputView {
  private func setup() {
    textField.text = "0"
    textField.font = TKTextStyle.num2.font
    textField.textColor = .Text.primary
    textField.textAlignment = .right
    
    addSubview(tokenButton)
    addSubview(textField)
  }
}

private extension CGFloat {
  static let itemHeight: CGFloat = 36
  static let horizontalSpacing: CGFloat = 8
}

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
