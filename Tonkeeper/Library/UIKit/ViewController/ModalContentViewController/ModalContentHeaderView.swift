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
  
  let titleLabel = UILabel()
  
  let topDescriptionLabel = UILabel()
  
  let bottomDescriptionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  let fixBottomDescriptionLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fillProportionally
    return stackView
  }()
  
  private let imageViewContainer = UIView()
  
  private let imageBottomSpacing = SpacingView(horizontalSpacing: .none, verticalSpacing: .constant(.imageBottomSpace))
  private let topDescriptionSpacing = SpacingView(horizontalSpacing: .none, verticalSpacing: .constant(.descriptionSpace))
  
  private var imageViewWidthConstraint: NSLayoutConstraint?
  private var imageViewHeigthConstraint: NSLayoutConstraint?
  
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
    switch model.image {
    case .none:
      imageViewContainer.isHidden = true
      imageBottomSpacing.isHidden = true
      imageView.backgroundColor = .clear
      imageView.image = nil
    case let .image(image, tintColor, backgroundColor):
      imageViewContainer.isHidden = false
      imageBottomSpacing.isHidden = false
      imageView.backgroundColor = backgroundColor
      imageView.image = image
      imageView.tintColor = tintColor
      if let image = image {
        imageViewWidthConstraint?.constant = image.size.width
        imageViewHeigthConstraint?.constant = image.size.height
      } else {
        imageViewWidthConstraint?.constant = .imageSide
        imageViewHeigthConstraint?.constant = .imageSide
      }
    }
    
    topDescriptionLabel.isHidden = model.topDescription == nil
    topDescriptionSpacing.isHidden = model.topDescription == nil
    topDescriptionLabel.attributedText = model.topDescription?
      .attributed(with: .body1, alignment: .center, color: .Text.secondary)
    
    titleLabel.attributedText = model.title?
      .attributed(with: .h2, alignment: .center, color: .Text.primary)
    bottomDescriptionLabel.attributedText = model.bottomDescription?
      .attributed(with: .body1, alignment: .center, color: .Text.secondary)
    fixBottomDescriptionLabel.attributedText = model.fixBottomDescription?
      .attributed(with: .body1, alignment: .center, color: .Text.secondary)
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
    
    imageViewWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: .imageSide)
    imageViewWidthConstraint?.isActive = true
    imageViewHeigthConstraint = imageView.heightAnchor.constraint(equalToConstant: .imageSide)
    imageViewHeigthConstraint?.isActive = true
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      imageView.topAnchor.constraint(equalTo: imageViewContainer.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: imageViewContainer.bottomAnchor),
      imageView.centerXAnchor.constraint(equalTo: imageViewContainer.centerXAnchor)
    ])
  }
}

private extension CGFloat {
  static let imageSide: CGFloat = 96
  static let imageBottomSpace: CGFloat = 20
  static let descriptionSpace: CGFloat = 4
}
