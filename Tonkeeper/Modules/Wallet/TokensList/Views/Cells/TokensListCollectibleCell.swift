//
//  TokensListCollectibleCell.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

final class TokensListCollectibleCell: UICollectionViewCell, Reusable, ConfigurableView {
  struct Model: Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let isOnSale: Bool
    
    init(title: String,
         subtitle: String,
         isOnSale: Bool = false) {
      self.title = title
      self.subtitle = subtitle
      self.isOnSale = isOnSale
    }
  }

  private let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .Background.content
    return imageView
  }()
  private let labelContainer: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    return view
  }()
  private let saleImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = .Icons.Collectible.sale
    imageView.tintColor = .white
    imageView.isHidden = true
    return imageView
  }()
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.textColor = .Text.primary
    label.applyTextStyleFont(.label2)
    label.numberOfLines = 1
    label.backgroundColor = .Background.content
    return label
  }()
  private let subtitleLabel: UILabel = {
    let label = UILabel()
    label.textColor = .Text.secondary
    label.applyTextStyleFont(.body3)
    label.numberOfLines = 1
    label.backgroundColor = .Background.content
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: Model) {
    titleLabel.text = model.title
    subtitleLabel.text = model.subtitle
    saleImageView.isHidden = !model.isOnSale
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let saleIconFrame = CGRect(x: bounds.width - .saleIconSide - .saleIconSpace,
                               y: .saleIconSpace,
                               width: .saleIconSide, height: .saleIconSide)
    saleImageView.frame = saleIconFrame
  }
}

private extension TokensListCollectibleCell {
  func setup() {
    contentView.layer.cornerRadius = 16
    contentView.layer.masksToBounds = true
    
    contentView.backgroundColor = .Background.page
    
    labelContainer.addSubview(titleLabel)
    labelContainer.addSubview(subtitleLabel)
    contentView.addSubview(labelContainer)
    contentView.addSubview(imageView)
    contentView.addSubview(saleImageView)
    
    labelContainer.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
      imageView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
      imageView.heightAnchor.constraint(equalTo: imageView.heightAnchor),
      
      labelContainer.topAnchor.constraint(equalTo: imageView.bottomAnchor),
      labelContainer.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      labelContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor),
      labelContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      
      
      titleLabel.topAnchor.constraint(equalTo: labelContainer.topAnchor,
                                      constant: UIEdgeInsets.labelContainerInsets.top),
      titleLabel.leftAnchor.constraint(equalTo: labelContainer.leftAnchor,
                                       constant: UIEdgeInsets.labelContainerInsets.left),
      titleLabel.rightAnchor.constraint(equalTo: labelContainer.rightAnchor,
                                        constant: -UIEdgeInsets.labelContainerInsets.right),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
      subtitleLabel.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor,
                                            constant: -UIEdgeInsets.labelContainerInsets.bottom),
      subtitleLabel.leftAnchor.constraint(equalTo: labelContainer.leftAnchor,
                                          constant: UIEdgeInsets.labelContainerInsets.left),
      subtitleLabel.rightAnchor.constraint(equalTo: labelContainer.rightAnchor, constant:
                                            -UIEdgeInsets.labelContainerInsets.right),
    ])
  }
}

private extension UIEdgeInsets {
  static let labelContainerInsets: UIEdgeInsets = .init(top: 8, left: 12, bottom: 8, right: 12)
}

private extension CGFloat {
  static let saleIconSide: CGFloat = 13
  static let saleIconSpace: CGFloat = 10
}
