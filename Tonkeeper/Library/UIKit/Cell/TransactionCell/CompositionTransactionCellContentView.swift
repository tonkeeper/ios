//
//  CompositionTransactionCellContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 6.8.23..
//

import UIKit

final class CompositionTransactionCellContentView: UIView, ContainerCollectionViewCellContent {
  struct Model {
    let transactionContentModels: [TransactionCellContentView.Model]
  }
  
  var transactionContentViews = [TransactionCellContentView]()
  
  func prepareForReuse() {
    transactionContentViews.forEach { $0.prepareForReuse() }
  }

  func configure(model: Model) {
    var views = [TransactionCellContentView]()
    for (index, transactionView) in transactionContentViews.enumerated() {
      guard index < model.transactionContentModels.count else {
        transactionView.removeFromSuperview()
        continue
      }
      views.append(transactionView)
    }
    model.transactionContentModels.enumerated().forEach { index, transactionModel in
      let view: TransactionCellContentView
      if index < views.count {
        view = views[index]
      } else {
        view = TransactionCellContentView()
        views.append(view)
        addSubview(view)
      }
      
      view.configure(model: transactionModel)
      view.isSeparatorVisible = index < model.transactionContentModels.count - 1
    }
    transactionContentViews = views
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()

    var y: CGFloat = 0
    transactionContentViews.forEach { view in
      let size = view.sizeThatFits(.init(width: bounds.size.width, height: 0))
      view.frame.origin = .init(x: 0, y: y)
      view.frame.size = size
      y = view.frame.maxY
    }
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let height = transactionContentViews.reduce(CGFloat(0)) { partialResult, view in
      return partialResult + view.sizeThatFits(size).height
      
    }
    return CGSize(width: size.width, height: height)
  }
}
