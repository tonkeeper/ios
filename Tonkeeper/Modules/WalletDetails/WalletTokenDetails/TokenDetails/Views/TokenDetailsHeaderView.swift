//
//  TokenDetailsHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 14.7.23..
//

import UIKit

final class TokenDetailsHeaderView: UIView, ConfigurableView {
  
  struct Model {
    let amount: String
    let fiatAmount: String?
    let fiatPrice: String?
    let image: Image
    let buttonRowModel: ButtonsRowView.Model
  }
  
  let amountLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h2)
    label.textColor = .Text.primary
    label.textAlignment = .left
    return label
  }()
  
  let fiatAmountLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.textAlignment = .left
    return label
  }()
  
  let fiatPriceLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.textAlignment = .left
    return label
  }()
  
  let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.layer.masksToBounds = true
    return imageView
  }()
  
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  let buttonsRowView = ButtonsRowView()
  
  let buttonsSeparatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  weak var imageLoader: ImageLoader?
  
  private let priceStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let topContainer = UIView()
  
  private let fiatPriceTopSpacingView = SpacingView(verticalSpacing: .constant(.fiatPriceTopSpacing))
  
  private var priceStackViewBottomConstraint: NSLayoutConstraint?
  private var imageBottomConstraint: NSLayoutConstraint?
  
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
    amountLabel.text = model.amount
    fiatAmountLabel.text = model.fiatAmount
    if let fiatPrice = model.fiatPrice {
      fiatPriceLabel.isHidden = false
      fiatPriceTopSpacingView.isHidden = false
      fiatPriceLabel.text = fiatPrice
      imageBottomConstraint?.isActive = false
      priceStackViewBottomConstraint?.isActive = true
    } else {
      fiatPriceLabel.isHidden = true
      fiatPriceTopSpacingView.isHidden = true
      priceStackViewBottomConstraint?.isActive = false
      imageBottomConstraint?.isActive = true
    }
    
    switch model.image {
    case let .image(image, tinColor, backgroundColor):
      imageView.image = image
      imageView.tintColor = tinColor
      imageView.backgroundColor = backgroundColor
    case let .url(url):
      imageLoader?.loadImage(imageURL: url, imageView: imageView, size: .init(width: .imageViewSide, height: .imageViewSide))
    }
    
    buttonsRowView.configure(model: model.buttonRowModel)
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    imageView.layoutIfNeeded()
    imageView.layer.cornerRadius = imageView.bounds.width/2
  }
}

private extension TokenDetailsHeaderView {
  func setup() {
    addSubview(topContainer)
    addSubview(buttonsRowView)
    addSubview(buttonsSeparatorView)
    
    topContainer.addSubview(priceStackView)
    topContainer.addSubview(imageView)
    topContainer.addSubview(separatorView)
    
    priceStackView.addArrangedSubview(amountLabel)
    priceStackView.addArrangedSubview(fiatAmountLabel)
    priceStackView.addArrangedSubview(fiatPriceTopSpacingView)
    priceStackView.addArrangedSubview(fiatPriceLabel)
    
    priceStackView.setCustomSpacing(.amountBottomSpacing, after: amountLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    topContainer.translatesAutoresizingMaskIntoConstraints = false
    priceStackView.translatesAutoresizingMaskIntoConstraints = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    buttonsRowView.translatesAutoresizingMaskIntoConstraints = false
    buttonsSeparatorView.translatesAutoresizingMaskIntoConstraints = false
    
    priceStackViewBottomConstraint = priceStackView.bottomAnchor.constraint(equalTo: separatorView.topAnchor,
                                                                            constant: -.topContainerBottomSpacing)
    
    imageBottomConstraint = imageView.bottomAnchor.constraint(equalTo: separatorView.topAnchor,
                                                              constant: -.topContainerBottomSpacing)
    
    NSLayoutConstraint.activate([
      topContainer.topAnchor.constraint(equalTo: topAnchor),
      topContainer.leftAnchor.constraint(equalTo: leftAnchor),
      topContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      buttonsRowView.topAnchor.constraint(equalTo: topContainer.bottomAnchor, constant: .buttonsRowVerticalSpacing),
      buttonsRowView.leftAnchor.constraint(equalTo: leftAnchor),
      buttonsRowView.rightAnchor.constraint(equalTo: rightAnchor),
      buttonsRowView.bottomAnchor.constraint(equalTo: buttonsSeparatorView.topAnchor, constant: -.buttonsRowVerticalSpacing),
      
      buttonsSeparatorView.leftAnchor.constraint(equalTo: leftAnchor),
      buttonsSeparatorView.rightAnchor.constraint(equalTo: rightAnchor),
      buttonsSeparatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
      buttonsSeparatorView.heightAnchor.constraint(equalToConstant: .separatorHeight),
      
      priceStackView.topAnchor.constraint(equalTo: topContainer.topAnchor, constant: .topContainerTopSpacing),
      priceStackView.leftAnchor.constraint(equalTo: topContainer.leftAnchor, constant: .topContainerSideSpacing),
      
      imageView.widthAnchor.constraint(equalToConstant: .imageViewSide),
      imageView.heightAnchor.constraint(equalToConstant: .imageViewSide),
      imageView.topAnchor.constraint(equalTo: topContainer.topAnchor, constant: .topContainerTopSpacing),
      imageView.leftAnchor.constraint(equalTo: priceStackView.rightAnchor, constant: .imageViewLeftSpacing),
      imageView.rightAnchor.constraint(equalTo: topContainer.rightAnchor, constant: -.topContainerSideSpacing),
      
      separatorView.leftAnchor.constraint(equalTo: topContainer.leftAnchor),
      separatorView.rightAnchor.constraint(equalTo: topContainer.rightAnchor),
      separatorView.heightAnchor.constraint(equalToConstant: .separatorHeight),
      separatorView.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let fiatPriceTopSpacing: CGFloat = 12
  static let topContainerTopSpacing: CGFloat = 16
  static let topContainerSideSpacing: CGFloat = 28
  static let topContainerBottomSpacing: CGFloat = 28
  static let imageViewLeftSpacing: CGFloat = 16
  static let imageViewSide: CGFloat = 64
  static let separatorHeight: CGFloat = 0.5
  static let amountBottomSpacing: CGFloat = 2
  static let buttonsRowVerticalSpacing: CGFloat = 16
}
