//
//  TonConnectConfirmationFeeView.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 30.10.2023.
//

import UIKit
import TKUIKit

final class TonConnectConfirmationFeeView: UIView, ConfigurableView {
  let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.tertiary
    label.textAlignment = .left
    return label
  }()
  
  let feeLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.tertiary
    label.textAlignment = .right
    return label
  }()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let title: String
    let fee: String
  }
  
  func configure(model: Model) {
    titleLabel.text = model.title
    feeLabel.text = model.fee
  }
}

private extension TonConnectConfirmationFeeView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(feeLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
      stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}
