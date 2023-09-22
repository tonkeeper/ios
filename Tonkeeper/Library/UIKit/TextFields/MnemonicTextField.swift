//
//  MnemonicTextField.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit
import TKUIKit

protocol MnemonicTextFieldDelegate: AnyObject {
  func didTapNextButton(textField: MnemonicTextField)
  func didPaste(text: String, textField: MnemonicTextField)
}

final class MnemonicTextField: UIControlClosure {
  
  weak var delegate: MnemonicTextFieldDelegate?
  
  enum ValidationState {
    case valid
    case invalid
  }
  
  var text: String? {
    get { textField.text }
    set { textField.text = newValue }
  }
  
  var placeholder: String? {
    get { placeholderLabel.text }
    set { placeholderLabel.text = newValue }
  }
  
  var validationState: ValidationState = .valid {
    didSet {
      updateAppearance()
    }
  }
  
  private let container: TextFieldContainer = {
    let container = TextFieldContainer()
    container.isUserInteractionEnabled = false
    return container
  }()
  let textField: UITextField = {
    let textField = UITextField()
    textField.backgroundColor = .clear
    textField.font = TextStyle.body1.font
    textField.textColor = .Text.primary
    textField.tintColor = .Text.accent
    textField.keyboardType = .alphabet
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.keyboardAppearance = .dark
    textField.returnKeyType = .next
    return textField
  }()
  let placeholderLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.textAlignment = .right
    label.numberOfLines = 1
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    .init(width: UIView.noIntrinsicMetric,
          height: .height)
  }
  
  @discardableResult
  override func becomeFirstResponder() -> Bool {
    let result = textField.becomeFirstResponder()
    return result
  }
  
  @discardableResult
  override func resignFirstResponder() -> Bool {
    let result = textField.resignFirstResponder()
    return result
  }
}

// MARK: - Private

private extension MnemonicTextField {
  func setup() {
    addSubview(container)
    addSubview(textField)
    addSubview(placeholderLabel)
    
    addAction(.init(handler: { [weak self] in
      self?.textField.becomeFirstResponder()
    }), for: .touchUpInside)
    
    textField.addTarget(self, action: #selector(didStartEditing), for: .editingDidBegin)
    textField.addTarget(self, action: #selector(didEndEditing), for: .editingDidEnd)
    textField.addTarget(self, action: #selector(didEdit), for: .editingChanged)
    textField.delegate = self
    
    setupConstraints()
  }
  
  func setupConstraints() {
    container.translatesAutoresizingMaskIntoConstraints = false
    textField.translatesAutoresizingMaskIntoConstraints = false
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: topAnchor),
      container.leftAnchor.constraint(equalTo: leftAnchor),
      container.rightAnchor.constraint(equalTo: rightAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      placeholderLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: .contentHorizontalSpace),
      placeholderLabel.widthAnchor.constraint(equalToConstant: .orderLabelWidth),
      placeholderLabel.heightAnchor.constraint(equalToConstant: .orderLabelHeight),
      
      textField.centerYAnchor.constraint(equalTo: centerYAnchor),
      textField.leftAnchor.constraint(equalTo: placeholderLabel.rightAnchor, constant: .textLeftSpacing),
      textField.rightAnchor.constraint(equalTo: rightAnchor, constant: -.contentHorizontalSpace)
    ])
  }
  
  func updateAppearance() {
    switch validationState {
    case .valid:
      container.validationState = .valid
      textField.tintColor = .Field.activeBorder
    case .invalid:
      container.validationState = .invalid
      textField.tintColor = .Field.errorBorder
    }
  }
  
  @objc
  func didStartEditing() {
    container.state = .active
    sendActions(for: .editingDidBegin)
  }
  
  @objc
  func didEndEditing() {
    container.state = .inactive
    sendActions(for: .editingDidEnd)
  }
  
  @objc
  func didEdit() {
    sendActions(for: .editingChanged)
  }
}

extension MnemonicTextField: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    delegate?.didTapNextButton(textField: self)
    return true
  }
  
  func textField(_ textField: UITextField,
                 shouldChangeCharactersIn range: NSRange,
                 replacementString string: String) -> Bool {
    if UIPasteboard.general.hasStrings,
       let pasteString = UIPasteboard.general.string?.replacingOccurrences(of: "\n", with: " "),
       string == pasteString {
      delegate?.didPaste(text: pasteString, textField: self)
      return false
    }
    return true
  }
}

private extension CGFloat {
  static let contentVerticalSpace: CGFloat = 16
  static let contentHorizontalSpace: CGFloat = 12
  static let textLeftSpacing: CGFloat = 12
  static let orderLabelWidth: CGFloat = 28
  static let orderLabelHeight: CGFloat = 24
  static let height: CGFloat = 56
}
