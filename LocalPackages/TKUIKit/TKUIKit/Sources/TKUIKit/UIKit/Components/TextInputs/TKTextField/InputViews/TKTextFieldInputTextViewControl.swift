import UIKit

public protocol TKTextInputTextViewFormatterDelegate: AnyObject {
  func textView(_ textView: TKTextInputTextViewControl, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
}

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
  
  public weak var formatterDelegate: TKTextInputTextViewFormatterDelegate?
  public var cursorLabel: UILabel?
  
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
    keyboardType = .alphabet
    autocapitalizationType = .none
    autocorrectionType = .no
    keyboardAppearance = .dark
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
  
  public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    guard let formatterDelegate else { return true }
    return formatterDelegate.textView(self, shouldChangeTextIn: range, replacementText: text)
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

extension TKTextInputTextViewControl {
  public func setupCursorLabel(withTitle title: NSAttributedString, placeholderWidth: CGFloat, inputText: String) {
    let cursorLabel = UILabel()
    cursorLabel.attributedText = title
    cursorLabel.sizeToFit()
    
    self.cursorLabel?.removeFromSuperview()
    self.cursorLabel = cursorLabel
    addSubview(cursorLabel)
    
    textContainerInset.right = cursorLabel.sizeThatFits(bounds.size).width + .cursorHorizontalPadding
    
    cursorLabel.frame.origin.y = 0

    updateCursorLabel(placeholderWidth: placeholderWidth, inputText: inputText)
  }
  
  func updateCursorLabel(placeholderWidth: CGFloat, inputText: String) {
    guard let label = cursorLabel else { return }
    guard let cursorPosition = self.position(from: self.beginningOfDocument, offset: inputText.count) else { return }
   
    let rect = self.caretRect(for: cursorPosition)
    let cursorX = rect.origin.x
    let labelX = cursorX + rect.size.width + .cursorHorizontalPadding
    let placeholderX = placeholderWidth + .cursorHorizontalPadding
    
    let isNewLineStarted = cursorX == 0 && !inputText.isEmpty
    let isMovedToPlaceholder = cursorX == 0 && inputText.isEmpty
    let isMovedFromPlaceholder = cursorX > 0 && cursorX < placeholderX && label.frame.origin.x == placeholderX
    let isNeedAnimation = isMovedToPlaceholder || isMovedFromPlaceholder
    
    // TODO: Fix label padding when on new lane
    let targetX = isMovedToPlaceholder ? placeholderX : labelX
    var targetY = isNewLineStarted ? label.frame.origin.y + label.frame.height : rect.origin.y
    targetY += 1
    
    if isNeedAnimation {
      UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
        label.frame.origin.x = targetX
        label.frame.origin.y = targetY
      }
    } else {
      label.frame.origin.x = targetX
      label.frame.origin.y = targetY
    }
  }
}

private extension CGFloat {
  static let cursorHorizontalPadding: CGFloat = 6
}
