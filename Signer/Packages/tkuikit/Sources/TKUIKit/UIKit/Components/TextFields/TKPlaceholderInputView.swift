import UIKit

public final class TKPlaceholderInputView: UIView, TKTextInputView {
  
  public var placeholder = "" {
    didSet {
      placeholderLabel.text = placeholder
    }
  }
  
  private let textInputView: TKTextInputView
  private let placeholderLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.body1.font
    label.textColor = .Text.secondary
    label.textAlignment = .left
    label.numberOfLines = 1
    label.isUserInteractionEnabled = false
    label.layer.anchorPoint = .init(x: 0, y: 0.5)
    return label
  }()
  
  private var placeholderTopConstraint: NSLayoutConstraint?
  
  public init(textInputView: TKTextInputView) {
    self.textInputView = textInputView
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    placeholderLabel.layoutIfNeeded()
    placeholderLabel.frame.origin.x = 0
  }
  
  @discardableResult
  public override func becomeFirstResponder() -> Bool {
    return textInputView.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    return textInputView.resignFirstResponder()
  }

  // MARK: - TKTextInputView
  
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var text: String {
    get {
      textInputView.text
    }
    set {
      textInputView.text = newValue
      updatePlaceholderState(inputText: newValue)
    }
  }
  
  public func didUpdateState(_ state: TKTextInputContainerState) {
    textInputView.didUpdateState(state)
  }
}

private extension TKPlaceholderInputView {
  func setup() {
    textInputView.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
      self?.updatePlaceholderState(inputText: text)
    }
    textInputView.didBeginEditing = { [weak self] in
      self?.didBeginEditing?()
    }
    textInputView.didEndEditing = { [weak self] in
      self?.didEndEditing?()
    }
    textInputView.shouldPaste = { [weak self] text in
      (self?.shouldPaste?(text) ?? true)
    }
    
    addSubview(textInputView)
    addSubview(placeholderLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    textInputView.translatesAutoresizingMaskIntoConstraints = false
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

    placeholderTopConstraint = placeholderLabel
      .topAnchor
      .constraint(equalTo: textInputView.topAnchor, constant: .placeholderTopMargin)
    placeholderTopConstraint?.isActive = true

    NSLayoutConstraint.activate([
      textInputView.topAnchor.constraint(equalTo: topAnchor),
      textInputView.leftAnchor.constraint(equalTo: leftAnchor),
      textInputView.bottomAnchor.constraint(equalTo: bottomAnchor),
      textInputView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func updatePlaceholderState(inputText: String) {
    self.layoutIfNeeded()
    let placeholderTransform: CGAffineTransform
    let inputViewTransform: CGAffineTransform
    if inputText.isEmpty {
      placeholderTransform = .identity
      inputViewTransform = .identity
      placeholderTopConstraint?.constant = .placeholderTopMargin
    } else {
      placeholderTransform = .init(scaleX: .placeholderScale, y: .placeholderScale)
      inputViewTransform = .init(translationX: 0, y: .inputYOffset)
      placeholderTopConstraint?.constant = -3
    }
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.placeholderLabel.transform = placeholderTransform
      self.textInputView.transform = inputViewTransform
      self.placeholderLabel.layoutIfNeeded()
      self.layoutIfNeeded()
    }
  }
}

private extension CGFloat {
  static let placeholderScale: CGFloat = 0.75
  static let placeholderTopMargin: CGFloat = 10
  static let inputYOffset: CGFloat = 7
}
