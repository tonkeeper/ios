//
//  ActivityEmptyActivityEmptyView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

final class ActivityEmptyView: UIView, ConfigurableView {
  
  struct Model {
    let title: NSAttributedString
    let description: NSAttributedString
    let buyButtonTitle: String
    let receiveButtonTitle: String
  }
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  let descriptionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  let buyButton = TKButton(configuration: .secondaryMedium)
  let receiveButton = TKButton(configuration: .secondaryMedium)
  
  private let contentContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let buttonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = .interButtonSpace
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
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    descriptionLabel.attributedText = model.description
    buyButton.titleLabel.text = model.buyButtonTitle
    receiveButton.titleLabel.text = model.receiveButtonTitle
  }
}

// MARK: - Private

private extension ActivityEmptyView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentContainer)
    
    contentContainer.addArrangedSubview(titleLabel)
    contentContainer.addArrangedSubview(descriptionLabel)
    contentContainer.addArrangedSubview(buttonsStackView)
    
    contentContainer.setCustomSpacing(.titleBottomSpace, after: titleLabel)
    contentContainer.setCustomSpacing(.descriptionBottomSpace, after: descriptionLabel)
    
    buttonsStackView.addArrangedSubview(buyButton)
    buttonsStackView.addArrangedSubview(receiveButton)
    
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
      contentContainer.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }
}

private extension CGFloat {
  static let interButtonSpace: CGFloat = 12
  static let titleBottomSpace: CGFloat = 4
  static let descriptionBottomSpace: CGFloat = 24
}
