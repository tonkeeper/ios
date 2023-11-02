//
//  TokenListTokenCell.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

final class TokenListTokenCell: ContainerCollectionViewCell<BalanceCellContentView>, Reusable {
  
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
  
  weak var imageLoader: ImageLoader? {
    didSet {
      cellContentView.imageLoader = imageLoader
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: Model) {
    let textContentModel = DefaultCellTextContentView.Model(
      title: model.title,
      amount: model.amount?.attributed(with: .label1, alignment: .right, color: .Text.primary),
      subamount: nil,
      topLeftDescriptionValue: model.price,
      topLeftDescriptionSubvalue: model.priceDiff,
      topRightDescriptionValue: model.fiatAmount
    )
    let contentModel = DefaultCellContentView.Model(
      textContentModel: textContentModel,
      image: model.image
    )
    cellContentView.configure(model: .init(defaultContentModel: contentModel))
  }
}
