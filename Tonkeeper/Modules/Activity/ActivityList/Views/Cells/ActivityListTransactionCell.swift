//
//  ActivityListTransactionCell.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class ActivityListTransactionCell: ContainerCollectionViewCell<TransactionCellContentView>, Reusable {
  
  struct Model: Hashable {
    let id = UUID()
    let icon: UIImage?
    let name: String
    let subtitle: String
    let amount: NSAttributedString
    let time: String
    let isFailed: Bool
    let comment: String?
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
  
  var isInGroup = false {
    didSet {
      didUpdateIsInGroup()
    }
  }
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    isFirstCell = false
    isLastCell = false
    separatorView.isHidden = true
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    separatorView.frame = .init(x: ContentInsets.sideSpace,
                                y: bounds.height - .separatorWidth,
                                width: bounds.width - ContentInsets.sideSpace,
                                height: .separatorWidth)
  }
  
  func configure(model: Model) {
    let textContentModel = DefaultCellTextContentView.Model(
      leftTopTitle: model.name,
      leftTopRightTitle: nil,
      rightTopTitle: model.amount,
      leftMiddleTitle: model.subtitle,
      leftMiddleRightTitle: nil,
      rightMiddleTitle: model.time,
      leftBottomTitle: nil,
      rightBottomTitle: nil
    )
    let contentModel = DefaultCellContentView.Model(
      textContentModel: textContentModel,
      image: model.icon
    )
    var statusModel: TransactionCellContentView.TransactionCellStatusView.Model?
    if model.isFailed {
      statusModel = .init(status: "Failed".attributed(with: .body2, color: .Accent.orange))
    }
    
    var commentModel: TransactionCellContentView.TransactionCellCommentView.Model?
    if let comment = model.comment {
      commentModel = .init(comment: comment.attributed(with: .body2, color: .Text.primary))
    }
    
    let transactionCellModel = TransactionCellContentView.Model(
      defaultContentModel: contentModel,
      statusModel: statusModel,
      commentModel: commentModel)
    
    cellContentView.configure(model: transactionCellModel)
  }
}

private extension ActivityListTransactionCell {
  func setup() {
    contentView.addSubview(separatorView)
    layer.masksToBounds = true
    cellContentView.defaultCellContentView.imageView.backgroundColor = .Background.contentTint
    cellContentView.defaultCellContentView.imageView.tintColor = .Icon.secondary
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
  
  func didUpdateIsInGroup() {
    separatorView.isHidden = isLastCell || !isInGroup
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}
