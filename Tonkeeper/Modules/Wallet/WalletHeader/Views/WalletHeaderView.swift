//
//  WalletHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class WalletHeaderView: UIView, ConfigurableView {
  
  let titleView = WalletHeaderTitleView()
  
  let topWalletHeaderBannersContainerView = WalletHeaderBannersContainerView()
  let bottomWalletHeaderBannersContainerView = WalletHeaderBannersContainerView()
  
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
  
  let dateLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let addressTopSpacer = SpacingView(
    horizontalSpacing: .none,
    verticalSpacing: .constant(.topSpacing)
  )
  
  let buttonsView = ButtonsRowView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - ConfigurableView
  
  struct Model {
    enum Subtitle {
      case address(String)
      case date(String)
    }
    let balance: String
    let subtitle: Subtitle?
  }
  
  func configure(model: Model) {
    balanceLabel.text = model.balance
    
    switch model.subtitle {
    case .address(let address):
      addressButton.setTitle(address, for: .normal)
      addressButton.isHidden = false
      dateLabel.isHidden = true
      addressTopSpacer.isHidden = false
    case .date(let date):
      dateLabel.attributedText = date.attributed(with: .body2, alignment: .center, color: .Text.secondary)
      dateLabel.isHidden = false
      addressButton.isHidden = true
      addressTopSpacer.isHidden = false
    case .none:
      dateLabel.isHidden = true
      addressButton.isHidden = true
      addressTopSpacer.isHidden = true
    }
  }
}

private extension WalletHeaderView {
  func setup() {
    stackView.addArrangedSubview(topWalletHeaderBannersContainerView)
    stackView.addArrangedSubview(balanceLabel)
    stackView.addArrangedSubview(dateLabel)
    stackView.addArrangedSubview(addressButton)
    
    addSubview(stackView)
    addSubview(buttonsView)
    addSubview(bottomWalletHeaderBannersContainerView)
    addSubview(titleView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    buttonsView.translatesAutoresizingMaskIntoConstraints = false
    titleView.translatesAutoresizingMaskIntoConstraints = false
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    addressButton.translatesAutoresizingMaskIntoConstraints = false
    bottomWalletHeaderBannersContainerView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      titleView.topAnchor.constraint(equalTo: topAnchor),
      titleView.leftAnchor.constraint(equalTo: leftAnchor),
      titleView.rightAnchor.constraint(equalTo: rightAnchor),
      
      stackView.topAnchor.constraint(equalTo: titleView.bottomAnchor, constant: .amountTopSpacing),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
        .withPriority(.defaultHigh),
      
      buttonsView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: .buttonsTopSpacing),
      buttonsView.leftAnchor.constraint(equalTo: leftAnchor),
      buttonsView.rightAnchor.constraint(equalTo: rightAnchor),
      buttonsView.heightAnchor.constraint(equalToConstant: 82),
      
      dateLabel.heightAnchor.constraint(equalToConstant: 36),
      
      addressButton.heightAnchor.constraint(equalToConstant: 36),
      
      bottomWalletHeaderBannersContainerView.topAnchor.constraint(equalTo: buttonsView.bottomAnchor, constant: 6),
      bottomWalletHeaderBannersContainerView.leftAnchor.constraint(equalTo: leftAnchor),
      bottomWalletHeaderBannersContainerView.rightAnchor.constraint(equalTo: rightAnchor),
      bottomWalletHeaderBannersContainerView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh)
    ])
  }
}

private extension CGFloat {
  static let amountTopSpacing: CGFloat = 28
  static let topSpacing: CGFloat = 8
  static let buttonsTopSpacing: CGFloat = 16
}
