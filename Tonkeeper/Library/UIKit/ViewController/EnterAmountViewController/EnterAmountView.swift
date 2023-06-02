//
//  EnterAmountView.swift
//  Tonkeeper
//
//  Created by Grigory on 1.6.23..
//

import UIKit

final class EnterAmountView: UIView {

  static var amountTextStyle: TextStyle = .num1
  static var currencyCodeTextStyle: TextStyle = .num2
  static let amountCurrencyCodeSpace: CGFloat = 8
  
  private let bottomContainer = UIView()
  let inputContainer = UIView()
  
  private let centerContainer: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    view.layer.cornerRadius = 16
    view.layer.masksToBounds = true
    return view
  }()
  
  let amountTextField: UITextField = {
    let textField = UITextField()
    textField.font = EnterAmountView.amountTextStyle.font
    textField.textColor = .Text.primary
    textField.textAlignment = .right
    textField.keyboardAppearance = .dark
    textField.keyboardType = .decimalPad
    textField.tintColor = .Accent.blue
    return textField
  }()
  
  let currencyLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(EnterAmountView.currencyCodeTextStyle)
    label.textColor = .Text.secondary
    label.textAlignment = .center
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    return label
  }()
  
  let maxButton: Button = {
    let button = Button(configuration: .secondarySmall)
    button.titleLabel.text = "Max"
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }()
  
  let remainingLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.textAlignment = .right
    return label
  }()
  
  var amountWidthLimit: CGFloat {
    bounds.width - .inputContainerSideSpacing * 2
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension EnterAmountView {
  func setup() {
    addSubview(centerContainer)
    addSubview(bottomContainer)
    
    centerContainer.addSubview(inputContainer)
    inputContainer.addSubview(amountTextField)
    inputContainer.addSubview(currencyLabel)
    bottomContainer.addSubview(maxButton)
    bottomContainer.addSubview(remainingLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    centerContainer.translatesAutoresizingMaskIntoConstraints = false
    inputContainer.translatesAutoresizingMaskIntoConstraints = false
    amountTextField.translatesAutoresizingMaskIntoConstraints = false
    currencyLabel.translatesAutoresizingMaskIntoConstraints = false
    bottomContainer.translatesAutoresizingMaskIntoConstraints = false
    maxButton.translatesAutoresizingMaskIntoConstraints = false
    remainingLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      centerContainer.topAnchor.constraint(equalTo: topAnchor),
      centerContainer.leftAnchor.constraint(equalTo: leftAnchor),
      centerContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      inputContainer.centerYAnchor.constraint(equalTo: centerContainer.centerYAnchor),
      inputContainer.centerXAnchor.constraint(equalTo: centerContainer.centerXAnchor),
      inputContainer.leftAnchor.constraint(greaterThanOrEqualTo: centerContainer.leftAnchor, constant: .inputContainerSideSpacing),
      inputContainer.rightAnchor.constraint(lessThanOrEqualTo: centerContainer.rightAnchor, constant: .inputContainerSideSpacing),
      
      amountTextField.topAnchor.constraint(equalTo: inputContainer.topAnchor),
      amountTextField.leftAnchor.constraint(equalTo: inputContainer.leftAnchor),
      amountTextField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),
      
      currencyLabel.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),
      currencyLabel.leftAnchor.constraint(equalTo: amountTextField.rightAnchor, constant: EnterAmountView.amountCurrencyCodeSpace),
      currencyLabel.rightAnchor.constraint(equalTo: inputContainer.rightAnchor),
      
      bottomContainer.topAnchor.constraint(equalTo: centerContainer.bottomAnchor, constant: .bottomContainerTopSpace),
      bottomContainer.leftAnchor.constraint(equalTo: leftAnchor),
      bottomContainer.rightAnchor.constraint(equalTo: rightAnchor),
      bottomContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.bottomContainerBottomSpace),
      
      maxButton.topAnchor.constraint(equalTo: bottomContainer.topAnchor),
      maxButton.leftAnchor.constraint(equalTo: leftAnchor),
      maxButton.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor),
      
      remainingLabel.centerYAnchor.constraint(equalTo: maxButton.centerYAnchor),
      remainingLabel.rightAnchor.constraint(equalTo: bottomContainer.rightAnchor),
      remainingLabel.leftAnchor.constraint(equalTo: maxButton.rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let inputContainerSideSpacing: CGFloat = 40
  static let bottomContainerTopSpace: CGFloat = 16
  static let bottomContainerBottomSpace: CGFloat = 40
}
