import UIKit
import TKUIKit

final public class BuySellAmountTextField: UITextField {
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = .clear
    font = TKTextStyle.amountInput.font
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
}
