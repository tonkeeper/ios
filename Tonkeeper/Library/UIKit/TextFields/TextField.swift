//
//  TextField.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

final class TextField: UIControlClosure {
  
  enum PlaceholderMode {
    case topStick
    case noStick
  }
  
  enum ValidationState {
    case valid
    case invalid
  }
  
  weak var delegate: UITextViewDelegate?
  
  var placeholder: String? {
    get { placeholderLabel.text }
    set { placeholderLabel.text = newValue }
  }
  
  var validationState: ValidationState = .valid {
    didSet {
      updateAppearance()
    }
  }
  
  var placeholderMode: PlaceholderMode = .topStick {
    didSet {
      updatePlaceholderModeAppearance()
    }
  }
  
  var isPasteButtonAvailable = false {
    didSet {
      updatePasteButtonVisibility()
    }
  }
  
  var isScanQRCodeButtonAvailable = false {
    didSet {
      updateScanQRCodeButtonVisibility()
    }
  }
  
  private let container = TextFieldContainer()
  let textView: UITextView = {
    let textView = UITextView()
    textView.backgroundColor = .clear
    textView.font = TextStyle.body1.font
    textView.textColor = .Text.primary
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainerInset = .init(
      top: TextStyle.body1.lineSpacing/2,
      left: 0,
      bottom: TextStyle.body1.lineSpacing/2,
      right: 0)
    textView.isScrollEnabled = false
    return textView
  }()
  
  private let placeholderLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.textAlignment = .left
    label.numberOfLines = 1
    label.layer.anchorPoint = .init(x: 0, y: 0.5)
    return label
  }()
  
  private let clearButton: UIButton = {
    let button = UIButton(type: .system)
    button.setImage(.Icons.TextField.clear, for: .normal)
    button.tintColor = .Icon.secondary
    button.isHidden = true
    return button
  }()
  
  private let pasteButton: UIButton = {
    let button = UIButton(type: .system)
    button.titleLabel?.applyTextStyleFont(.label1)
    button.setTitleColor(.Accent.blue, for: .normal)
    button.setTitle("Paste", for: .normal)
    return button
  }()
  
  let scanQRButton: UIButton = {
    let button = UIButton(type: .system)
    button.tintColor = .Accent.blue
    button.setImage(.Icons.Buttons.scanQR, for: .normal)
    return button
  }()
  
  private let buttonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  private var textViewTopConstraint: NSLayoutConstraint?
  private var textViewBottomConstraint: NSLayoutConstraint?
  
  private var placeholderCenterYConstraint: NSLayoutConstraint?
  private var placeholderTopConstraint: NSLayoutConstraint?
  private var placeholderLeftConstraint: NSLayoutConstraint?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func becomeFirstResponder() -> Bool {
    let result = textView.becomeFirstResponder()
    updateState(isFirstResponder: result)
    return result
  }
  
  override func resignFirstResponder() -> Bool {
    let result = textView.resignFirstResponder()
    updateState(isFirstResponder: result)
    return result
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    placeholderLabel.layoutIfNeeded()
    placeholderLabel.frame.origin.x = .placeholderLeftSpace
  }
}

private extension TextField {
  func setup() {
    addAction(.init(handler: { [weak self] in
      self?.textView.becomeFirstResponder()
    }), for: .touchUpInside)
    
    clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    pasteButton.addTarget(self, action: #selector(pasteButtonTapped), for: .touchUpInside)
    
    container.isUserInteractionEnabled = false
    
    textView.delegate = self
    
    addSubview(container)
    addSubview(textView)
    addSubview(placeholderLabel)
    addSubview(clearButton)
    addSubview(buttonsStackView)
    
    buttonsStackView.addArrangedSubview(pasteButton)
    buttonsStackView.setCustomSpacing(.interButtonsSpace, after: pasteButton)
    buttonsStackView.addArrangedSubview(scanQRButton)
    
    setupConstraints()
    
    updatePlaceholderModeAppearance()
    updateAppearance()
    updateState(isFirstResponder: false)
  }
  
  func setupConstraints() {
    container.translatesAutoresizingMaskIntoConstraints = false
    textView.translatesAutoresizingMaskIntoConstraints = false
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
    clearButton.translatesAutoresizingMaskIntoConstraints = false
    buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
    
    textViewTopConstraint = textView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
    textViewBottomConstraint = textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
//      .withPriority(.defaultHigh)
    textViewTopConstraint?.isActive = true
    textViewBottomConstraint?.isActive = true
    
    placeholderTopConstraint = placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: .placeholderTopActiveSpace)
    placeholderCenterYConstraint = placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
    placeholderCenterYConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      textView.leftAnchor.constraint(equalTo: leftAnchor, constant: .textViewLeftSpace),
      textView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.textViewRightSpace),
//        .withPriority(.defaultHigh),
      
      clearButton.widthAnchor.constraint(equalToConstant: .clearButtonSide),
      clearButton.heightAnchor.constraint(equalToConstant: .clearButtonSide),
      clearButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -.clearButtonRightSpace),
      clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),

      container.topAnchor.constraint(equalTo: topAnchor),
      container.leftAnchor.constraint(equalTo: leftAnchor),
      container.rightAnchor.constraint(equalTo: rightAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor),

      buttonsStackView.topAnchor.constraint(equalTo: topAnchor),
      buttonsStackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.buttonsStackRightSpace),
      buttonsStackView.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }
  
  func updateAppearance() {
    switch validationState {
    case .valid:
      container.validationState = .valid
      textView.tintColor = .Field.activeBorder
    case .invalid:
      container.validationState = .invalid
      textView.tintColor = .Field.errorBorder
    }
  }
  
  func updatePlaceholderModeAppearance() {
    switch placeholderMode {
    case .noStick:
      textViewTopConstraint?.constant = .textViewTopSpace
      textViewBottomConstraint?.constant = -.textViewBottomSpace
    case .topStick:
      textViewTopConstraint?.constant = .textViewPlaceholderTopSpace
      textViewBottomConstraint?.constant = -.textViewPlaceholderBottomSpace
    }
  }
  
  func updatePasteButtonVisibility() {
    pasteButton.isHidden = !textView.text.isEmpty || !isPasteButtonAvailable
  }
  
  func updateScanQRCodeButtonVisibility() {
    scanQRButton.isHidden = !textView.text.isEmpty || !isScanQRCodeButtonAvailable
  }
  
  func updateState(isFirstResponder: Bool) {
    clearButton.isHidden = textView.text.isEmpty || !isFirstResponder
    updatePasteButtonVisibility()
    updateScanQRCodeButtonVisibility()
  
    switch placeholderMode {
    case .noStick:
      placeholderLabel.isHidden = !textView.text.isEmpty
    case .topStick:
      isFirstResponder || !textView.text.isEmpty
      ? movePlaceholderTop()
      : movePlaceholderBottom()
    }
  }

  func movePlaceholderTop() {
    layoutIfNeeded()
    
    placeholderCenterYConstraint?.isActive = false
    placeholderTopConstraint?.isActive = true
    let transform = CGAffineTransform(scaleX: .placeholderScale, y: .placeholderScale)
    
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.placeholderLabel.transform = transform
      self.layoutIfNeeded()
    }
  }
  
  func movePlaceholderBottom() {
    layoutIfNeeded()
    
    placeholderCenterYConstraint?.isActive = true
    placeholderTopConstraint?.isActive = false
    let transform = CGAffineTransform.identity
    
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.placeholderLabel.transform = transform
      self.layoutIfNeeded()
    }
  }
  
  @objc
  func clearButtonTapped() {
    textView.text = nil
    updateState(isFirstResponder: textView.isFirstResponder)
    delegate?.textViewDidChange?(textView)
  }
  
  @objc
  func pasteButtonTapped() {
    textView.text = UIPasteboard.general.string
    updateState(isFirstResponder: textView.isFirstResponder)
  }
}

extension TextField: UITextViewDelegate {
  func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
    updateState(isFirstResponder: true)
    container.state = .active
    return delegate?.textViewShouldBeginEditing?(textView) ?? true
  }
  
  func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
    updateState(isFirstResponder: false)
    container.state = .inactive
    return delegate?.textViewShouldEndEditing?(textView) ?? true
  }
  
  func textViewDidChange(_ textView: UITextView) {
    updateState(isFirstResponder: textView.isFirstResponder)
    delegate?.textViewDidChange?(textView)
  }
  
  func textView(_ textView: UITextView,
                shouldChangeTextIn range: NSRange,
                replacementText text: String) -> Bool {
    return delegate?.textView?(
      textView,
      shouldChangeTextIn: range,
      replacementText: text) ?? true
  }
}

private extension CGFloat {
  static let textViewLeftSpace: CGFloat = 16
  static let textViewRightSpace: CGFloat = 40
  static let textViewPlaceholderTopSpace: CGFloat = 28
  static let textViewPlaceholderBottomSpace: CGFloat = 12
  static let textViewTopSpace: CGFloat = 16
  static let textViewBottomSpace: CGFloat = 16
  static let placeholderScale: CGFloat = 0.75
  
  static let placeholderLeftSpace: CGFloat = 16
  static let placeholderTopActiveSpace: CGFloat = 12
  
  static let clearButtonSide: CGFloat = 16
  static let clearButtonRightSpace: CGFloat = 16
  
  static let buttonsStackRightSpace: CGFloat = 17
  static let interButtonsSpace: CGFloat = 30
}
