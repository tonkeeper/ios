//
//  ActivityListCompositionTransactionCell.swift
//  Tonkeeper
//
//  Created by Grigory on 6.8.23..
//

import UIKit

final class ActivityListCompositionTransactionCell: ContainerCollectionViewCell<CompositionTransactionCellContentView>, Reusable {
  
  weak var imageLoader: ImageLoader? {
    didSet {
      cellContentView.imageLoader = imageLoader
    }
  }
  
  struct Model {
    var childTransactionModels: [TransactionCellContentView.Model]
    
    init(childTransactionModels: [TransactionCellContentView.Model]) {
      self.childTransactionModels = childTransactionModels
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
    cellContentView.configure(model: .init(transactionContentModels: model.childTransactionModels))
  }
}

private extension ActivityListCompositionTransactionCell {
  func setup() {
    layer.masksToBounds = true
    layer.cornerRadius = 16
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}

