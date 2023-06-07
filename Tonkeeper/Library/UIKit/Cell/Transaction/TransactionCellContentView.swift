//
//  TransactionCellContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class TransactionCellContentView: UIView, ContainerCollectionViewCellContent {
  
  let defaultCellContentView = DefaultCellContentView()
  let statusView = TransactionCellStatusView()
  let commentView = TransactionCellCommentView()
  
  struct Model {
    let defaultContentModel: DefaultCellContentView.Model
    let statusModel: TransactionCellStatusView.Model?
    let commentModel: TransactionCellCommentView.Model?
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let defaultCellContentSize = defaultCellContentView.sizeThatFits(.init(width: bounds.width, height: 0))
    defaultCellContentView.frame.size = defaultCellContentSize
    defaultCellContentView.frame.origin = .zero
    
    var bottomContentY = defaultCellContentView.frame.maxY
    
    let statusSize = statusView.sizeThatFits(.init(width: bounds.width, height: 0))
    statusView.frame = CGRect(x: defaultCellContentView.textContentFrame.minX,
                              y: bottomContentY,
                              width: defaultCellContentView.textContentFrame.width,
                              height: statusSize.height)
    
    
    bottomContentY = statusView.frame.maxY
    
    let commentSize = commentView.sizeThatFits(.init(width: bounds.width, height: 0))
    commentView.frame = CGRect(x: defaultCellContentView.textContentFrame.minX,
                               y: bottomContentY,
                               width: defaultCellContentView.textContentFrame.width,
                               height: commentSize.height)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let defaultCellContentHeight = defaultCellContentView.sizeThatFits(size).height
    let statusHeight = statusView.sizeThatFits(size).height
    let commentHeight = commentView.sizeThatFits(size).height
    let height = defaultCellContentHeight + statusHeight + commentHeight
    return .init(width: size.width, height: height)
  }
  
  func configure(model: Model) {
    defaultCellContentView.configure(model: model.defaultContentModel)
    
    if let statusModel = model.statusModel {
      statusView.configure(model: statusModel)
      statusView.isHidden = false
    } else {
      statusView.isHidden = true
    }
    
    if let commentModel = model.commentModel {
      commentView.configure(model: commentModel)
      commentView.isHidden = false
    } else {
      commentView.isHidden = true
    }
    setNeedsLayout()
  }
  
  func prepareForReuse() {
    defaultCellContentView.prepareForReuse()
    statusView.prepareForReuse()
    commentView.prepareForReuse()
  }
}

private extension TransactionCellContentView {
  func setup() {
    addSubview(defaultCellContentView)
    addSubview(statusView)
    addSubview(commentView)
  }
}
