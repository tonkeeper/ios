import UIKit

public final class TKTextField: UIControl {
  
  public struct RightItem {
    public enum Mode {
      case always
      case empty
      case nonEmpty
    }
    
    public let view: UIView
    public let mode: Mode
    
    public init(view: UIView, mode: Mode) {
      self.view = view
      self.mode = mode
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
    set { 
      textFieldInputView.inputText = newValue
      updateRightItemsVisibility()
    }
  }
  
  public var placeholder: String {
    get { textFieldInputView.placeholder }
    set { textFieldInputView.placeholder = newValue }
  }
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var rightItems = [RightItem]() {
    didSet {
      didSetRightItems()
    }
  }
  
  var textFieldState: TKTextFieldState = .inactive {
    didSet {
      didUpdateState()
    }
  }
  
  private let backgroundView = TKTextFieldBackgroundView()
  private let textFieldInputView: TKTextFieldInputView
  private let rightItemsContainer = UIStackView()
  
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
    textFieldInputView.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    textFieldInputView.resignFirstResponder()
  }
}

private extension TKTextField {
  func setup() {
    textFieldInputView.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
      self?.updateRightItemsVisibility()
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
      top: 20,
      left: 16,
      bottom: 20,
      right: 16
    )
    
    didUpdateState()
    
    backgroundView.isUserInteractionEnabled = false
    
    addSubview(backgroundView)
    addSubview(textFieldInputView)
    addSubview(rightItemsContainer)
    
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
      make.top.left.bottom.equalTo(self)
      make.right.equalTo(rightItemsContainer.snp.left)
    }
    
    rightItemsContainer.snp.makeConstraints { make in
      make.top.right.bottom.equalTo(self)
      make.width.equalTo(0).priority(.high)
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
  
  func didSetRightItems() {
    rightItemsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    rightItems.forEach { rightItem in
      rightItem.view.setContentHuggingPriority(.required, for: .horizontal)
      rightItem.view.setContentCompressionResistancePriority(.required, for: .horizontal)
      rightItemsContainer.addArrangedSubview(rightItem.view)
    }
    updateRightItemsVisibility()
  }
  
  func updateRightItemsVisibility() {
    let isEmpty = text.isEmpty
    rightItems.forEach { rightItem in
      switch rightItem.mode {
      case .always:
        rightItem.view.isHidden = false
      case .empty:
        rightItem.view.isHidden = !isEmpty
      case .nonEmpty:
        rightItem.view.isHidden = isEmpty
      }
    }
  }
}
