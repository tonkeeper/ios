//
//  ContainerCollectionViewCell.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

protocol ContainerCollectionViewCellContent: ConfigurableView {
  func prepareForReuse()
}

class ContainerCollectionViewCell<CellContentView: ContainerCollectionViewCellContent>: UICollectionViewCell, ConfigurableView {

  let cellContentView = CellContentView()
  let highlightView = HighlightContainerView()
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  var isSeparatorVisible = true {
    didSet {
      separatorView.isHidden = !isSeparatorVisible
    }
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

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: CellContentView.Model) {
    cellContentView.configure(model: model)
  }
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let cellContentViewSize = cellContentView.sizeThatFits(.init(width: targetSize.width, height: 0))
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size = cellContentViewSize
    return modifiedAttributes
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    highlightView.frame = contentView.bounds
    cellContentView.frame = highlightView.bounds
    separatorView.frame = .init(x: ContentInsets.sideSpace,
                                y: bounds.height - .separatorWidth,
                                width: bounds.width - ContentInsets.sideSpace,
                                height: .separatorWidth)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cellContentView.prepareForReuse()
    isFirstCell = false
    isLastCell = false
    updateSeparatorVisibility()
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
    
    separatorView.isHidden = isLastCell || !isSeparatorVisible
  }
  
  func updateSeparatorVisibility() {
    separatorView.isHidden = isLastCell || !isSeparatorVisible || highlightView.isHighlighted
  }
}

private extension ContainerCollectionViewCell {
  func setup() {
    layer.masksToBounds = true
    contentView.addSubview(highlightView)
    contentView.addSubview(separatorView)
    highlightView.addSubview(cellContentView)
    highlightView.didUpdateIsHighlighted = { [weak self] _ in
      self?.updateSeparatorVisibility()
    }
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorWidth: CGFloat = 0.5
}

