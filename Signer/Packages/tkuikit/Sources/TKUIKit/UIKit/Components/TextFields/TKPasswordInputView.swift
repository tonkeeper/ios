import UIKit

public final class TKPasswordInputView: UIView, TKTextInputView {
    
  private var state: TKTextInputContainerState = .inactive
  private let textFieldInputView: TKTextFieldInputView
  private var passwordText = "" {
    didSet {
      didUpdateText?(passwordText)
    }
  }
  
  public init(textFieldInputView: TKTextFieldInputView) {
    self.textFieldInputView = textFieldInputView
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @discardableResult
  public override func becomeFirstResponder() -> Bool {
    return textFieldInputView.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    return textFieldInputView.resignFirstResponder()
  }
  
  // MARK: - TKTextInputView
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var text: String {
    get {
      passwordText
    }
    set {
      passwordText = newValue
      textFieldInputView.textField.attributedText = getHashPasswordString()
    }
  }
  
  public func didUpdateState(_ state: TKTextInputContainerState) {
    self.state = state
    textFieldInputView.textField.attributedText = getAttributedPasswordHashString(
      string: textFieldInputView.textField.text ?? "",
      state: state
    )
    switch state {
    case .active, .inactive:
      textFieldInputView.textField.tintColor = state.tintColor
    case .error:
      textFieldInputView.textField.tintColor = .Accent.red
    }
  }
}

private extension TKPasswordInputView {
  func setup() {
    textFieldInputView.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
    }
    textFieldInputView.didBeginEditing = { [weak self] in
      self?.didBeginEditing?()
    }
    
    textFieldInputView.didEndEditing = { [weak self] in
      self?.didEndEditing?()
    }
    textFieldInputView.shouldPaste = { [weak self] text in
      (self?.shouldPaste?(text) ?? true)
    }
    
    textFieldInputView.textField.textAlignment = .center
    textFieldInputView.textField.delegate = self
    
    addSubview(textFieldInputView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    textFieldInputView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      textFieldInputView.topAnchor.constraint(equalTo: topAnchor),
      textFieldInputView.leftAnchor.constraint(equalTo: leftAnchor),
      textFieldInputView.bottomAnchor.constraint(equalTo: bottomAnchor),
      textFieldInputView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func getHashPasswordString() -> NSAttributedString {
    let hashPassword = (0..<passwordText.count).map { _ in "\u{25CF}" }.joined()
    return getAttributedPasswordHashString(
      string: hashPassword,
      state: state
    )
  }
  
  func getAttributedPasswordHashString(string: String,
                                       state: TKTextInputContainerState) -> NSAttributedString {
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

extension TKPasswordInputView: UITextFieldDelegate {
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
