import UIKit

public final class TKMnemonicTextField: UIControl {
  
  public var indexNumber: Int = 0{
    didSet {
      indexNumberLabel.text = "\(indexNumber):"
    }
  }
  
  public var isActive: Bool {
    textFieldInputView.isActive
  }
  
  public var isValid = true {
    didSet {
      didUpdateActiveState()
    }
  }
  
  public var text: String! {
    get { textFieldInputView.inputText }
    set { textFieldInputView.inputText = newValue }
  }
  
  public var placeholder: String {
    get { textFieldInputView.placeholder }
    set { textFieldInputView.placeholder = newValue }
  }
  
  public var accessoryView: UIView? {
    get { textFieldInputView.accessoryView }
    set { textFieldInputView.accessoryView = newValue }
  }
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var didTapReturn: (() -> Void)?
  
  var textFieldState: TKTextFieldState = .inactive {
    didSet {
      didUpdateState()
    }
  }
  
  private let backgroundView = TKTextFieldBackgroundView()
  private lazy var textFieldInputView: TKTextFieldInputView = {
    let textInputControl = TKTextInputTextFieldControl()
    textInputControl.delegate = self
    let textFieldInputView = TKTextFieldInputView(textInputControl: textInputControl)
    return textFieldInputView
  }()
  private let indexNumberLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.body1.font
    label.textColor = .Text.secondary
    label.textAlignment = .right
    label.numberOfLines = 1
    label.isUserInteractionEnabled = false
    return label
  }()
  
  public init() {
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @discardableResult
  public override func becomeFirstResponder() -> Bool {
    textFieldInputView.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    textFieldInputView.resignFirstResponder()
  }
}

private extension TKMnemonicTextField {
  func setup() {
    textFieldInputView.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
    }
    
    textFieldInputView.didBeginEditing = { [weak self] in
      self?.didUpdateActiveState()
      self?.didBeginEditing?()
    }
    
    textFieldInputView.didEndEditing = { [weak self] in
      self?.didUpdateActiveState()
      self?.didEndEditing?()
    }
    
    textFieldInputView.shouldPaste = { [weak self] in
      self?.shouldPaste?($0) ?? true
    }
    
    textFieldInputView.padding = UIEdgeInsets(
      top: 16,
      left: 12,
      bottom: 16,
      right: 16
    )
    textFieldInputView.clearButtonMode = .never
    
    didUpdateState()
    
    backgroundView.isUserInteractionEnabled = false
    
    addSubview(backgroundView)
    addSubview(textFieldInputView)
    addSubview(indexNumberLabel)
    setupConstraints()
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.textFieldInputView.becomeFirstResponder()
    }), for: .touchUpInside)
  }
  
  func setupConstraints() {
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    textFieldInputView.snp.makeConstraints { make in
      make.top.bottom.right.equalTo(self)
      make.left.equalTo(indexNumberLabel.snp.right)
    }
    
    indexNumberLabel.snp.makeConstraints { make in
      make.centerY.equalTo(self)
      make.left.equalTo(self).inset(12)
      make.width.equalTo(28)
    }
  }
  
  func didUpdateState() {
    UIView.animate(withDuration: 0.2) { [backgroundView, textFieldInputView, textFieldState] in
      backgroundView.textFieldState = textFieldState
      textFieldInputView.textFieldState = textFieldState
    }
  }
  
  func didUpdateActiveState() {
    switch (isActive, isValid) {
    case (false, true):
      textFieldState = .inactive
    case (true, true):
      textFieldState = .active
    case (false, false):
      textFieldState = .error
    case (true, false):
      textFieldState = .error
    }
  }
}

extension TKMnemonicTextField: UITextFieldDelegate {
  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    guard let didTapReturn = didTapReturn else { return false }
    didTapReturn()
    return true
  }
}
