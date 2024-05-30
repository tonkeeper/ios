import UIKit

public final class TKTextInputTextFieldControl: UITextField, TKTextFieldInputViewControl {  

  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var inputText: String {
    get { text ?? "" }
    set { text = newValue }
  }
  
  public var isActive: Bool {
    isFirstResponder
  }
  
  public var accessoryView: UIView? {
    get { inputAccessoryView }
    set { inputAccessoryView = newValue }
  }
  
  public var textFieldState: TKTextFieldState = .inactive {
    didSet {
      didUpdateState()
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
}

private extension TKTextInputTextFieldControl {
  func setup() {
    backgroundColor = .clear
    font = TKTextStyle.body1.font
    textColor = .Text.primary
    tintColor = .Text.accent
    keyboardType = .alphabet
    autocapitalizationType = .none
    autocorrectionType = .no
    pasteDelegate = self

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
  
  func didUpdateState() {
    tintColor = textFieldState.tintColor
  }
}

extension TKTextInputTextFieldControl: UITextPasteDelegate {
  public func textPasteConfigurationSupporting(
    _ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting,
    transform item: UITextPasteItem) {
      guard let shouldPaste = shouldPaste else {
        item.setDefaultResult()
        return
      }
      guard let pasteString = UIPasteboard.general.string else {
        item.setNoResult()
        return
      }
      
      if shouldPaste(pasteString) {
        item.setDefaultResult()
      } else {
        item.setNoResult()
      }
  }
}

private extension CGFloat {
  static let height: CGFloat = 24
}
