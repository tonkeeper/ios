import UIKit

public final class TKMnemonicInputView: UIView, TKTextInputView {
  
  public var indexNumber = 0 {
    didSet {
      indexNumberLabel.text = "\(indexNumber):"
    }
  }
  
  private let textFieldInputView: TKTextFieldInputView
  private let indexNumberLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.body1.font
    label.textColor = .Text.secondary
    label.textAlignment = .left
    label.numberOfLines = 1
    label.isUserInteractionEnabled = false
    return label
  }()
  
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
      textFieldInputView.text
    }
    set {
      textFieldInputView.text = newValue
    }
  }
  
  public func didUpdateState(_ state: TKTextInputContainerState) {
    textFieldInputView.didUpdateState(state)
  }
}

private extension TKMnemonicInputView {
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
    
    addSubview(textFieldInputView)
    addSubview(indexNumberLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    textFieldInputView.translatesAutoresizingMaskIntoConstraints = false
    indexNumberLabel.translatesAutoresizingMaskIntoConstraints = false
    
    indexNumberLabel.setContentHuggingPriority(.required, for: .horizontal)
    indexNumberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

    NSLayoutConstraint.activate([
      indexNumberLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: .indexLabelLeftPadding),
      indexNumberLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      
      textFieldInputView.heightAnchor.constraint(equalToConstant: 32),
      textFieldInputView.topAnchor.constraint(equalTo: topAnchor),
      textFieldInputView.leftAnchor.constraint(equalTo: indexNumberLabel.rightAnchor, constant: .indexLabelRightPadding),
      textFieldInputView.bottomAnchor.constraint(equalTo: bottomAnchor),
      textFieldInputView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let indexLabelLeftPadding: CGFloat = 10
  static let indexLabelRightPadding: CGFloat = 12
}
