import UIKit

public protocol TKTextInputView: UIView {
  var didUpdateText: ((_ text: String) -> Void)? { get set }
  var didBeginEditing: (() -> Void)? { get set }
  var didEndEditing: (() -> Void)? { get set }
  var shouldPaste: ((String) -> Bool)? { get set }
  
  var text: String { get set }
  
  func didUpdateState(_ state: TKTextInputContainerState)
}

public enum TKTextInputContainerState {
  case inactive
  case active
  case error
  
  var backgroundColor: UIColor {
    switch self {
    case .inactive:
      return .Field.background
    case .active:
      return .Field.background
    case .error:
      return .Field.errorBackground
    }
  }
  
  var borderColor: UIColor {
    switch self {
    case .inactive:
      return UIColor.clear
    case .active:
      return UIColor.Field.activeBorder
    case .error:
      return UIColor.Field.errorBorder
    }
  }
  
  var tintColor: UIColor {
    switch self {
    case .active:
      return .Accent.blue
    case .inactive:
      return .Accent.blue
    case .error:
      return .Accent.red
    }
  }
}

public final class TKTextInputContainer<TextInputView: TKTextInputView>: UIView {
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var isValid = true {
    didSet {
      didUpdateIsValidAndIsActive()
    }
  }
  
  public var text: String {
    get {
      textInputView.text
    }
    set {
      textInputView.text = newValue
    }
  }
  
  private var isActive = false {
    didSet {
      didUpdateIsValidAndIsActive()
    }
  }
  
  private var state: TKTextInputContainerState = .inactive {
    didSet {
      didUpdateState()
    }
  }
  
  private let backgroundView = TKTextFieldBackgroundView()
  
  let textInputView: TextInputView
  
  public init(textInputView: TextInputView) {
    self.textInputView = textInputView
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @discardableResult
  public override func becomeFirstResponder() -> Bool {
    return textInputView.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    return textInputView.resignFirstResponder()
  }
}

private extension TKTextInputContainer {
  func setup() {
    addSubview(backgroundView)
    addSubview(textInputView)
    
    textInputView.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
    }
    
    textInputView.didBeginEditing = { [weak self] in
      self?.isActive = true
      self?.didBeginEditing?()
    }
    
    textInputView.didEndEditing = { [weak self] in
      self?.isActive = false
      self?.didEndEditing?()
    }
    
    textInputView.shouldPaste = { [weak self] text in
      return (self?.shouldPaste?(text) ?? true)
    }
    
    setupConstraints()
  }
  
  func setupConstraints() {
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    textInputView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor),
      
      textInputView.topAnchor.constraint(
        equalTo: topAnchor, constant: inputViewPadding.top
      ),
      textInputView.leftAnchor.constraint(
        equalTo: leftAnchor, constant: inputViewPadding.left
      ),
      textInputView.bottomAnchor.constraint(
        equalTo: bottomAnchor, constant: -inputViewPadding.bottom
      ),
      textInputView.rightAnchor.constraint(
        equalTo: rightAnchor, constant: -inputViewPadding.right
      )
    ])
  }
  
  func didUpdateState() {
    UIView.animate(withDuration: 0.2) { [state, backgroundView, textInputView] in
      backgroundView.state = state
      textInputView.didUpdateState(state)
    }
  }
  
  func didUpdateIsValidAndIsActive() {
    switch (isActive, isValid) {
    case (false, true):
      state = .inactive
    case (true, true):
      state = .active
    case (false, false):
      state = .error
    case (true, false):
      state = .error
    }
  }
}

private extension TKTextInputContainer {
  var inputViewPadding: UIEdgeInsets {
    .init(top: 12, left: 16, bottom: 12, right: 16)
  }
}
