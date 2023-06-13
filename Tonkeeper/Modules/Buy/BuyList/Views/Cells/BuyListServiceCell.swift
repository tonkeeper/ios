//
//  BuyListServiceCell.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

final class BuyListServiceCell: ContainerCollectionViewCell<ServiceCellContentView>, Reusable {
  
  struct Model: Hashable {
    let id = UUID()
    let logo: UIImage?
    let title: String
    let description: String?
    let token: String?
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
    let serviceCellModel = ServiceCellContentView.Model(
      logo: model.logo,
      title: model.title,
      description: model.description,
      token: model.token
    )
    cellContentView.configure(model: serviceCellModel)
  }
}

private extension BuyListServiceCell {
  func setup() {
    contentView.addSubview(separatorView)
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
  
  func didUpdateIsInGroup() {
    separatorView.isHidden = isLastCell || !isInGroup
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}

