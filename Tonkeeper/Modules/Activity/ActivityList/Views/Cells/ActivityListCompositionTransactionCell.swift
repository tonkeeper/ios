//
//  ActivityListCompositionTransactionCell.swift
//  Tonkeeper
//
//  Created by Grigory on 6.8.23..
//

import UIKit

protocol ActivityListCompositionTransactionCellDelegate: AnyObject {
  func activityListCompositionTransactionCell(
    _ activityListCompositionTransactionCell: ActivityListCompositionTransactionCell,
    didSelectTransactionAt index: Int
  )
  func activityListCompositionTransactionCell(
    _ activityListCompositionTransactionCell: ActivityListCompositionTransactionCell,
    didSelectNFTAt index: Int
  )
}

final class ActivityListCompositionTransactionCell: ContainerCollectionViewCell<CompositionTransactionCellContentView>, Reusable {
  
  weak var delegate: ActivityListCompositionTransactionCellDelegate?
  
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
    cellContentView.delegate = self
    isSeparatorVisible = false
  }
}

extension ActivityListCompositionTransactionCell: CompositionTransactionCellContentViewDelegate {
  func compositionTransactionCellContentView(
    _ compositionTransactionCell: CompositionTransactionCellContentView,
    didSelectTransactionAt index: Int) {
      delegate?.activityListCompositionTransactionCell(self,
                                                       didSelectTransactionAt: index)
  }
  
  func compositionTransactionCellContentView(_ compositionTransactionCell: CompositionTransactionCellContentView,
                                             didSelectNFTAt index: Int) {
    delegate?.activityListCompositionTransactionCell(self,
                                                     didSelectNFTAt: index)
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}

