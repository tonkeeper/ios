//
//  StakeInputView.swift
//
//
//  Created by Semyon on 13/05/2024.
//

import UIKit
import TKUIKit
import SnapKit

final class StakeInputView: UIView, UITextFieldDelegate {
  
  var didUpdateText: ((String?) -> Void)?
  var didBeginEditing: (() -> Void)?
  var didEndEditing: (() -> Void)?
  
  // MARK: - Spec
  
  enum Spec {
    static let backgroundColor = UIColor.Background.content
    static let cornerRadius: CGFloat = 16
  }
  
  let verticalStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.distribution = .fill
    stackView.spacing = 4
    return stackView
  }()
  
  let stakeInputBalanceView = StakeInputBalanceView()
  
  let horizontalStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.spacing = 8
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()
  
  lazy var textInputControl: UITextField = {
    let textField = UITextField()
    textField.keyboardAppearance = .dark
    textField.keyboardType = .decimalPad
    textField.textAlignment = .right
    textField.font = TKTextStyle.stakeInput.font
    textField.textColor = .Text.primary
    textField.placeholder = "0"
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.delegate = self
    return textField
  }()
  
  private let currencyLabel: UILabel = {
    let label = UILabel()
    label.text = "TON"
    label.font = TKTextStyle.num2.font
    label.textAlignment = .left
    label.textColor = .Text.secondary
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private let currencyContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = Spec.backgroundColor
    layer.cornerRadius = Spec.cornerRadius
    
    addSubview(verticalStackView)
    
    currencyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    currencyContainer.addSubview(currencyLabel)
    
    horizontalStackView.addArrangedSubview(textInputControl)
    horizontalStackView.addArrangedSubview(currencyContainer)
    
    verticalStackView.addArrangedSubview(horizontalStackView)
    verticalStackView.addArrangedSubview(stakeInputBalanceView)
    
    setupConstraints()
    
    textInputControl.addTarget(self, action: #selector(Self.textFieldDidChange(_:)), for: .editingChanged)
    
    stakeInputBalanceView.configure(amount: "500USD", isNeedIcon: false)
  }
  
  func setupConstraints() {
    currencyLabel.snp.makeConstraints { make in
      make.leading.trailing.bottom.equalToSuperview()
      make.top.equalToSuperview().inset(6)
    }
    
    verticalStackView.snp.makeConstraints { make in
      make.center.equalToSuperview()
      make.left.greaterThanOrEqualTo(self.snp.left).inset(20)
      make.right.lessThanOrEqualTo(self.snp.right).inset(-20)
    }
    textInputControl.snp.makeConstraints { make in
      make.width.lessThanOrEqualTo(self.snp.width).multipliedBy(0.8)
    }
  }
}

extension StakeInputView {
  
  @objc func textFieldDidChange(_ textField: UITextField) {
    didUpdateText?(textField.text)
  }
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    didBeginEditing?()
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    didEndEditing?()
  }
  
}
