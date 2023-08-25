//
//  TransactionCellNFTView.swift
//  Tonkeeper
//
//  Created by Grigory on 8.8.23..
//

import UIKit

extension TransactionCellContentView {
  
  final class TransactionCellNFTView: UIControl, ConfigurableView, ContainerCollectionViewCellContent {
    
    struct Model {
      let image: Image
      let name: String?
      let collectionName: String?
    }
    
    private var model: Model?
    
    private let contentView = UIView()
    private let imageView = UIImageView()
    private let nameLabel: UILabel = {
      let label = UILabel()
      label.applyTextStyleFont(.body2)
      label.textColor = .Text.primary
      label.numberOfLines = 1
      return label
    }()
    private let collectiomNameLabel: UILabel = {
      let label = UILabel()
      label.applyTextStyleFont(.body2)
      label.textColor = .Text.secondary
      label.numberOfLines = 1
      return label
    }()
    
    weak var imageLoader: ImageLoader?
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
      super.layoutSubviews()
      
      contentView.frame = CGRect(x: 0, y: 8, width: bounds.width, height: bounds.height - 8)
      
      imageView.frame = CGRect(x: 0, y: 0, width: .imageSize, height: .imageSize)
      
      let textWidth = contentView.bounds.width - .imageSize - .labelsSideSpace * 2
      nameLabel.sizeToFit()
      nameLabel.frame = CGRect(x: imageView.frame.maxX + .labelsSideSpace,
                               y: contentView.bounds.size.height/2 - nameLabel.frame.size.height,
                               width: textWidth,
                               height: nameLabel.frame.size.height)
      collectiomNameLabel.sizeToFit()
      collectiomNameLabel.frame = CGRect(x: imageView.frame.maxX + .labelsSideSpace,
                                         y: contentView.bounds.size.height/2,
                                         width: textWidth,
                                         height: collectiomNameLabel.frame.size.height)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      guard model != nil else { return .zero }
      let textAvailableWidth = size.width - .imageSize - .labelsSideSpace * 2
      let nameWidth = nameLabel.sizeThatFits(size).width
      let collectiomNameWidth = collectiomNameLabel.sizeThatFits(size).width
      let width = max(.width, min(textAvailableWidth, max(nameWidth, collectiomNameWidth)) + .imageSize + .labelsSideSpace * 2)
      return CGSize(width: width, height: .height + 8)
    }
    
    func configure(model: Model) {
      self.model = model
      nameLabel.text = model.name
      collectiomNameLabel.text = model.collectionName
      
      switch model.image {
      case let .image(image, tintColor, backgroundColor):
        imageView.image = image
        imageView.tintColor = tintColor
        imageView.backgroundColor = backgroundColor
      case let .url(url):
        imageLoader?.loadImage(imageURL: url, imageView: imageView, size: nil)
      }
      
      setNeedsLayout()
    }
    
    func prepareForReuse() {
      imageView.image = nil
      nameLabel.text = nil
      collectiomNameLabel.text = nil
      model = nil
    }
  }
}

private extension TransactionCellContentView.TransactionCellNFTView {
  func setup() {
    contentView.backgroundColor = .Background.contentTint
    contentView.isUserInteractionEnabled = false
    
    contentView.layer.cornerRadius = .cornerRadius
    contentView.layer.masksToBounds = true
    
    addSubview(contentView)
    contentView.addSubview(imageView)
    contentView.addSubview(nameLabel)
    contentView.addSubview(collectiomNameLabel)
  }
}

private extension CGFloat {
  static let topInset: CGFloat = 8
  static let cornerRadius: CGFloat = 12
  static let imageSize: CGFloat = 64
  static let width: CGFloat = 176
  static let height: CGFloat = 64
  static let labelsSideSpace: CGFloat = 12
}

