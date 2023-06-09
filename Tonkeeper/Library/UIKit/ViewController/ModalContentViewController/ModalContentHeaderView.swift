//
//  ModalContentHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

final class ModalContentHeaderView: UIView, ConfigurableView {
  
  let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .Accent.blue
    imageView.layer.masksToBounds = true
    return imageView
  }()
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    label.textAlignment = .center
    return label
  }()
  
  let topDescriptionLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.textAlignment = .center
    return label
  }()
  
  let bottomDescriptionLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.textAlignment = .center
    return label
  }()
  
  let fixBottomDescriptionLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.textAlignment = .center
    return label
  }()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fillProportionally
    return stackView
  }()
  
  private let imageViewContainer = UIView()
  
  private let imageBottomSpacing = SpacingView(horizontalSpacing: .none, verticalSpacing: .constant(.imageBottomSpace))
  private let topDescriptionSpacing = SpacingView(horizontalSpacing: .none, verticalSpacing: .constant(.descriptionSpace))
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    imageView.layoutIfNeeded()
    imageView.layer.cornerRadius = imageView.bounds.width / 2 
  }
  
  func configure(model: ModalContentViewController.Configuration.Header) {
    if let image = model.image {
      imageViewContainer.isHidden = false
      imageBottomSpacing.isHidden = false
      imageView.backgroundColor = image.backgroundColor
      imageView.image = image.image
    } else {
      imageViewContainer.isHidden = true
      imageBottomSpacing.isHidden = true
      imageView.backgroundColor = .clear
      imageView.image = nil
    }
    
    topDescriptionLabel.isHidden = model.topDescription == nil
    topDescriptionSpacing.isHidden = model.topDescription == nil
    topDescriptionLabel.text = model.topDescription
    
    titleLabel.text = model.title
    bottomDescriptionLabel.text = model.bottomDescription
    fixBottomDescriptionLabel.text = model.fixBottomDescription
  }
}

private extension ModalContentHeaderView {
  func setup() {
    addSubview(stackView)
    imageViewContainer.addSubview(imageView)
    
    stackView.addArrangedSubview(imageViewContainer)
    stackView.addArrangedSubview(imageBottomSpacing)
    stackView.addArrangedSubview(topDescriptionLabel)
    stackView.addArrangedSubview(topDescriptionSpacing)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(SpacingView(horizontalSpacing: .none, verticalSpacing: .constant(.descriptionSpace)))
    stackView.addArrangedSubview(bottomDescriptionLabel)
    stackView.addArrangedSubview(SpacingView(horizontalSpacing: .none, verticalSpacing: .constant(.descriptionSpace)))
    stackView.addArrangedSubview(fixBottomDescriptionLabel)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      imageView.topAnchor.constraint(equalTo: imageViewContainer.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: imageViewContainer.bottomAnchor),
      imageView.centerXAnchor.constraint(equalTo: imageViewContainer.centerXAnchor),
      imageView.widthAnchor.constraint(equalToConstant: .imageSide),
      imageView.heightAnchor.constraint(equalToConstant: .imageSide),
    ])
  }
}

private extension CGFloat {
  static let imageSide: CGFloat = 96
  static let imageBottomSpace: CGFloat = 20
  static let descriptionSpace: CGFloat = 4
}
