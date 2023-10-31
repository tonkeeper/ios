//
//  ActivityListTransactionCell.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class ActivityListTransactionCell: ContainerCollectionViewCell<TransactionCellContentView>, Reusable {
  
  struct Model: Hashable, Equatable {
    let id = UUID()
    let transactionModel: TransactionCellContentView.Model
    
    static func == (lhs: Self, rhs: Self) -> Bool {
      return lhs.id == rhs.id
    }
    
    var hashValue: Int {
      return id.hashValue
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
  }
  
  func configure(model: Model) {
    cellContentView.configure(model: model.transactionModel)
  }
}

private extension ActivityListTransactionCell {
  func setup() {
    cellContentView.defaultCellContentView.imageView.backgroundColor = .Background.contentTint
    cellContentView.defaultCellContentView.imageView.tintColor = .Icon.secondary
    cellContentView.isSeparatorVisible = false
    layer.masksToBounds = true
    layer.cornerRadius = 16
    isSeparatorVisible = false
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}
