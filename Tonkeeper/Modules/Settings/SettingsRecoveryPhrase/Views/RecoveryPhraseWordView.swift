//
//  RecoveryPhraseWordView.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import UIKit

final class RecoveryPhraseWordView: UIView, ConfigurableView {
  
  private let orderNumberLabel = UILabel()
  private let wordLabel = UILabel()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.spacing = 4
    stackView.alignment = .bottom
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
    let orderNumber: Int
    let word: String
  }
  
  func configure(model: Model) {
    orderNumberLabel.attributedText = "\(model.orderNumber)."
      .attributed(
        with: .body2,
        alignment: .left,
        color: .Text.secondary
      )
    wordLabel.attributedText = model.word
      .attributed(
        with: .body1,
        alignment: .left,
        color: .Text.primary
      )
  }
}

private extension RecoveryPhraseWordView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(orderNumberLabel)
    stackView.addArrangedSubview(wordLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    orderNumberLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      
      orderNumberLabel.widthAnchor.constraint(equalToConstant: 24)
    ])
  }
}
