//
//  WalletHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class WalletHeaderView: UIView, ConfigurableView {
  let balanceLabel: UILabel = {
    let label = UILabel()
    label.textColor = .Text.primary
    label.applyTextStyleFont(.num2)
    label.textAlignment = .center
    return label
  }()
  
  let addressButton: UIButton = {
    let button = UIButton(type: .custom)
    button.setTitleColor(.Text.secondary, for: .normal)
    button.setTitleColor(.Text.tertiary, for: .highlighted)
    button.titleLabel?.applyTextStyleFont(.body2)
    return button
  }()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let addressTopSpacer = SpacingView(
    horizontalSpacing: .none,
    verticalSpacing: .constant(.topSpacing)
  )
  
  let buttonsView = WalletHeaderButtonsView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let balance: String
    let address: String?
  }
  
  func configure(model: Model) {
    balanceLabel.text = model.balance
    
    addressButton.setTitle(model.address, for: .normal)
    addressButton.isHidden = model.address == nil
    addressTopSpacer.isHidden = model.address == nil
  }
}

private extension WalletHeaderView {
  func setup() {
    stackView.addArrangedSubview(balanceLabel)
    stackView.addArrangedSubview(addressTopSpacer)
    stackView.addArrangedSubview(addressButton)
    
    addSubview(stackView)
    addSubview(buttonsView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    buttonsView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: .amountTopSpacing),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      
      buttonsView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: .buttonsTopSpacing),
      buttonsView.leftAnchor.constraint(equalTo: leftAnchor),
      buttonsView.rightAnchor.constraint(equalTo: rightAnchor),
      buttonsView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let amountTopSpacing: CGFloat = 48
  static let topSpacing: CGFloat = 8
  static let buttonsTopSpacing: CGFloat = 16
}
