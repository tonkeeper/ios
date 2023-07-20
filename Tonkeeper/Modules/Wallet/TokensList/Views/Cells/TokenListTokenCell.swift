//
//  TokenListTokenCell.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

final class TokenListTokenCell: ContainerCollectionViewCell<DefaultCellContentView>, Reusable {
  
  struct Model: Hashable {
    let id = UUID()
    let image: Image
    let title: String
    let shortTitle: String?
    let price: String?
    let priceDiff: NSAttributedString?
    let amount: String?
    let fiatAmount: String?
  }
  
  var isFirstCell = false {
    didSet {
      didUpdateCellOrder()
    }
  }
  
  var isLastCell = false {
    didSet {
      didUpdateCellOrder()
    }
  }
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  weak var imageLoader: ImageLoader? {
    didSet {
      cellContentView.imageLoader = imageLoader
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: Model) {
    let textContentModel = DefaultCellTextContentView.Model(
      leftTopTitle: model.title,
      leftTopRightTitle: model.shortTitle,
      rightTopTitle: model.amount?.attributed(with: .label1, alignment: .right, color: .Text.primary),
      leftMiddleTitle: model.price,
      leftMiddleRightTitle: model.priceDiff,
      rightMiddleTitle: model.fiatAmount,
      leftBottomTitle: nil,
      rightBottomTitle: nil
    )
    let contentModel = DefaultCellContentView.Model(
      textContentModel: textContentModel,
      image: model.image
    )
    cellContentView.configure(model: contentModel)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    isFirstCell = false
    isLastCell = false
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    separatorView.frame = .init(x: ContentInsets.sideSpace,
                                y: bounds.height - .separatorWidth,
                                width: bounds.width - ContentInsets.sideSpace,
                                height: .separatorWidth)
  }
  
  override func select() {
    super.select()
    separatorView.isHidden = true
//    separatorView.alpha = 0
  }

  override func deselect() {
    super.deselect()
    separatorView.isHidden = false
//    separatorView.alpha = 1
  }
}

private extension TokenListTokenCell {
  func setup() {
    addSubview(separatorView)
    layer.masksToBounds = true
  }
  
  func didUpdateCellOrder() {
    switch (isLastCell, isFirstCell) {
    case (true, false):
      layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      layer.cornerRadius = .cornerRadius
    case (false, true):
      layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      layer.cornerRadius = .cornerRadius
    case (true, true):
      layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                             .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      layer.cornerRadius = .cornerRadius
    case (false, false):
      layer.cornerRadius = 0
    }
    
    separatorView.isHidden = isLastCell
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}
