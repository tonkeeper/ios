import UIKit
import TKUIKit

public final class CustomizeWalletInputControl: UIView, TKTextInputFieldInputControl {
  
  // MARK: - TKTextInputFieldInputControl
  
  public var didEditText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  public var text: String {
    get {
      inputControl.text
    }
    set {
      inputControl.text = newValue
    }
  }
  
  public var accessoryView: UIView? {
    get { inputControl.accessoryView }
    set { inputControl.accessoryView = newValue }
  }
  
  public func setState(_ state: TKTextInputFieldState) {
    inputControl.setState(state)
  }
  
  public var emoji = "" {
    didSet {
      emojiLabel.text = emoji
      animateEmojiLabel()
    }
  }
  
  public var placeholder = "" {
    didSet {
      inputControl.placeholder = placeholder
    }
  }
  
  private let inputControl: TKTextInputFieldPlaceholderInputControl
  private let emojiLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 32)
    label.textAlignment = .right
    label.isUserInteractionEnabled = false
    return label
  }()
  
  init(inputControl: TKTextInputFieldPlaceholderInputControl) {
    self.inputControl = inputControl
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @discardableResult
  public override func becomeFirstResponder() -> Bool {
    return inputControl.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    return inputControl.resignFirstResponder()
  }
  
  public override var isFirstResponder: Bool {
    inputControl.isFirstResponder
  }
}

private extension CustomizeWalletInputControl {
  func setup() {
    addSubview(inputControl)
    addSubview(emojiLabel)
    
    setupTextInputViewEvents()
    setupConstraints()
  }
  
  func setupTextInputViewEvents() {
    inputControl.didEditText = { [weak self] text in
      self?.didEditText?(text)
    }
    inputControl.didBeginEditing = { [weak self] in
      self?.didBeginEditing?()
    }
    inputControl.didEndEditing = { [weak self] in
      self?.didEndEditing?()
    }
    inputControl.shouldPaste = { [weak self] text in
      return (self?.shouldPaste?(text) ?? true)
    }
  }
  
  func setupConstraints() {
    inputControl.translatesAutoresizingMaskIntoConstraints = false
    emojiLabel.translatesAutoresizingMaskIntoConstraints = false
    
    emojiLabel.setContentHuggingPriority(.required, for: .horizontal)
    emojiLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    NSLayoutConstraint.activate([
      inputControl.topAnchor.constraint(equalTo: topAnchor),
      inputControl.leftAnchor.constraint(equalTo: leftAnchor),
      inputControl.bottomAnchor.constraint(equalTo: bottomAnchor),
      inputControl.rightAnchor.constraint(equalTo: emojiLabel.leftAnchor, constant: -8),
      
      emojiLabel.rightAnchor.constraint(equalTo: rightAnchor),
      emojiLabel.centerYAnchor.constraint(equalTo: inputControl.centerYAnchor)
    ])
  }
  
  private func animateEmojiLabel() {
    animateEmojiLabelTransform(CGAffineTransform(scaleX: 1.1, y: 1.1)) { [weak self] in
      self?.animateEmojiLabelTransform(.identity)
    }
  }
  
  private func animateEmojiLabelTransform(_ transform: CGAffineTransform,
                                          completion: (() -> Void)? = nil) {
    UIView.animate(
      withDuration: 0.1,
      delay: 0,
      options: [.curveEaseIn],
      animations: {
        self.emojiLabel.transform = transform
      },
      completion: { _ in
        completion?()
      })
  }
}

private extension CGFloat {
  static let emojiLabelSide: CGFloat = 36
}
