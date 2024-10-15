import UIKit

public final class TKTextInputTextViewControl: UITextView, TKTextFieldInputViewControl {
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var isActive: Bool {
    isFirstResponder
  }
  
  public var textFieldState: TKTextFieldState = .inactive {
    didSet {
      didUpdateState()
    }
  }
  
  public var inputText: String {
    get { text }
    set { text = newValue }
  }
  
  public var accessoryView: UIView? {
    get { inputAccessoryView }
    set { inputAccessoryView = newValue }
  }
  
  public init() {
    let storage = NSTextStorage()
    let manager = NSLayoutManager()
    let container = NSTextContainer()
    storage.addLayoutManager(manager)
    manager.addTextContainer(container)
    super.init(frame: .zero, textContainer: container)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKTextInputTextViewControl {
  func setup() {
    autocapitalizationType = .none
    autocorrectionType = .no
    isScrollEnabled = false
    backgroundColor = .clear
    delegate = self
    pasteDelegate = self
    textContainer.lineFragmentPadding = 0
    textContainerInset = .init(
      top: 0,
      left: 0,
      bottom: 0,
      right: 0)
    typingAttributes = TKTextStyle.body1.getAttributes(color: .Text.primary, alignment: .left, lineBreakMode: .byWordWrapping)
  }
  
  func didUpdateState() {
    tintColor = textFieldState.tintColor
  }
}

extension TKTextInputTextViewControl: UITextViewDelegate {  
  public func textViewDidChange(_ textView: UITextView) {
    didUpdateText?(textView.text)
  }
  
  public func textViewDidBeginEditing(_ textView: UITextView) {
    didBeginEditing?()
  }
  
  public func textViewDidEndEditing(_ textView: UITextView) {
    didEndEditing?()
  }
}

extension TKTextInputTextViewControl: UITextPasteDelegate {
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
