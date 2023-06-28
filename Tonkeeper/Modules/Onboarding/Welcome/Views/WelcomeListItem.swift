//
//  WelcomeListItem.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class WelcomeListItem: UIView, ConfigurableView {
  
  private let iconImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.tintColor = .Accent.blue
    imageView.contentMode = .center
    return imageView
  }()
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    return label
  }()
  
  private let descriptionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
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
    let title: NSAttributedString?
    let description: NSAttributedString?
    let icon: UIImage?
  }
  
  func configure(model: Model) {
    iconImageView.image = model.icon
    titleLabel.attributedText = model.title
    descriptionLabel.attributedText = model.description
  }
}

// MARK: - Private

private extension WelcomeListItem {
  func setup() {
    addSubview(iconImageView)
    addSubview(titleLabel)
    addSubview(descriptionLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      iconImageView.widthAnchor.constraint(equalToConstant: .iconSide),
      iconImageView.heightAnchor.constraint(equalToConstant: .iconSide),
      iconImageView.topAnchor.constraint(equalTo: topAnchor),
      iconImageView.leftAnchor.constraint(equalTo: leftAnchor),
      
      titleLabel.topAnchor.constraint(equalTo: topAnchor),
      titleLabel.leftAnchor.constraint(equalTo: iconImageView.rightAnchor, constant: .iconRightSpace),
      titleLabel.rightAnchor.constraint(equalTo: rightAnchor),
      
      descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: .descriptionTopSpace),
      descriptionLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor),
      descriptionLabel.rightAnchor.constraint(equalTo: titleLabel.rightAnchor),
      descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let iconSide: CGFloat = 28
  static let descriptionTopSpace: CGFloat = 3
  static let iconRightSpace: CGFloat = 16
}
