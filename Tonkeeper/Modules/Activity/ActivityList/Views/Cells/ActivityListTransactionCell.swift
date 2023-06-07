//
//  ActivityListTransactionCell.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class ActivityListTransactionCell: ContainerCollectionViewCell<DefaultCellContentView>, Reusable {
  
  struct Model: Hashable {
    let id = UUID()
    let icon: UIImage?
    let name: String
    let subtitle: String
    let amount: NSAttributedString
    let time: String
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
    cellContentView.configure(model: contentModel)
  }
}

private extension ActivityListTransactionCell {
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
