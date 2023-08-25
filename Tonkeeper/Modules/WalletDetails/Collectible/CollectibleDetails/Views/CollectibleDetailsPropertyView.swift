//
//  CollectibleDetailsPropertyView.swift
//  Tonkeeper
//
//  Created by Grigory on 23.8.23..
//

import UIKit

final class CollectibleDetailsPropertyView: UIView, ConfigurableView {
  
  private let titleLabel = UILabel()
  private let valueLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: String
    let value: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.attributed(
      with: .body1,
      alignment: .left,
      lineBreakMode: .byWordWrapping,
      color: .Text.secondary
    )
    
    valueLabel.attributedText = model.value.attributed(
      with: .body1,
      alignment: .left,
      lineBreakMode: .byWordWrapping,
      color: .Text.primary
    )
  }
}

private extension CollectibleDetailsPropertyView {
  func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = .cornerRadius
    layer.masksToBounds = true
    
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(valueLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: .topSpace),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: .sideSpace),
      stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.sideSpace),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.bottomSpace)
    ])
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let sideSpace: CGFloat = 16
  static let topSpace: CGFloat = 10
  static let bottomSpace: CGFloat = 12
}
