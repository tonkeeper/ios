import UIKit

public final class TKTextViewInputView: UIView, TKTextInputView {
  private let textView: UITextView = {
    let textView = UITextView()
    textView.backgroundColor = .clear
    textView.font = TKTextStyle.body1.font
    textView.textColor = .Text.primary
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainerInset = .init(
      top: 10,
      left: 0,
      bottom: 10,
      right: 0)
    textView.isScrollEnabled = false
    return textView
  }()
  
  public init() {
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 40)
  }
  
  // MARK: - TKTextInputView
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var text: String {
    get {
      textView.text ?? ""
    }
    set {
      textView.text = newValue
      didUpdateText?(newValue)
    }
  }
  
  public func didUpdateState(_ state: TKTextInputContainerState) {
    textView.tintColor = state.tintColor
  }
  
  @discardableResult
  public override func becomeFirstResponder() -> Bool {
    return textView.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    return textView.resignFirstResponder()
  }
}

private extension TKTextViewInputView {
  func setup() {
    textView.delegate = self
    textView.pasteDelegate = self
    
    addSubview(textView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    textView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.leftAnchor.constraint(equalTo: leftAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor),
      textView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

extension TKTextViewInputView: UITextViewDelegate {
  public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
    didBeginEditing?()
    return true
  }
  
  public func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
    didEndEditing?()
    return true
  }
  
  public func textViewDidChange(_ textView: UITextView) {
    didUpdateText?(textView.text)
  }
}

extension TKTextViewInputView: UITextPasteDelegate {
  public func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting,
                                               transform item: UITextPasteItem) {
    guard let shouldPaste = shouldPaste else {
      item.setDefaultResult()
      return
    }
    if shouldPaste(UIPasteboard.general.string ?? "") {
      item.setDefaultResult()
    } else {
      item.setNoResult()
    }
  }
}
