//
//  ActivityListCompositionTransactionCell.swift
//  Tonkeeper
//
//  Created by Grigory on 6.8.23..
//

import UIKit

final class ActivityListCompositionTransactionCell: ContainerCollectionViewCell<CompositionTransactionCellContentView>, Reusable {
  
  struct Model: Hashable, Equatable {
    let id = UUID()
    let childTransactionModels: [TransactionCellContentView.Model]
    
    static func == (lhs: Self, rhs: Self) -> Bool {
      return lhs.id == rhs.id
    }
    
    var hashValue: Int {
      return id.hashValue
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
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
//    contentView.backgroundColor = .Background.highlighted
    layer.masksToBounds = true
    layer.cornerRadius = 16
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}

