//
//  ModalContentListItemView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

final class ModalContentListItemView: UIControl, ConfigurableView {
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      didUpdateIsHighlighted()
    }
  }
  
  var isSeparatorHidden = false {
    didSet {
      separatorView.isHidden = isSeparatorHidden
    }
  }
  
  private let leftLabel = UILabel()
  private let rightTopLabel = UILabel()
  private let rightBottomLabel = UILabel()
  private let rightTopShimmerView = ShimmerView()
  private let rightBottomShimmerView = ShimmerView()
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  private let contentView = UIView()
  private let rightContentView = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: ModalContentViewController.Configuration.ListItem) {
    leftLabel.attributedText = model.left
      .attributed(with: .body1, alignment: .left, color: .Text.secondary)
    
    switch model.rightTop {
    case .value(let value):
      rightTopLabel.attributedText = value.attributed(with: .label1, alignment: .left, color: .Text.primary)
      rightTopLabel.isHidden = false
      rightTopShimmerView.isHidden = true
      rightTopShimmerView.stopAnimation()
    case .loading:
      rightTopLabel.attributedText = nil
      rightTopLabel.isHidden = true
      rightTopShimmerView.isHidden = false
      rightTopShimmerView.startAnimation()
    }
    
    switch model.rightBottom {
    case .value(let value):
      rightBottomLabel.attributedText = value?.attributed(with: .body2, alignment: .left, color: .Text.secondary)
      rightBottomLabel.isHidden = false
      rightBottomShimmerView.isHidden = true
      rightBottomShimmerView.stopAnimation()
    case .loading:
      rightBottomLabel.attributedText = nil
      rightBottomLabel.isHidden = true
      rightBottomShimmerView.isHidden = false
      rightBottomShimmerView.startAnimation()
    }
    
    setNeedsLayout()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let contentFrame = CGRect(x: .contentPadding, y: .contentPadding, width: bounds.width - .contentPadding*2, height: bounds.height - .contentPadding*2)
    contentView.frame = contentFrame
    
    layoutLeftLabel()
    layoutRight()
    
    separatorView.frame = CGRect(x: .contentPadding, y: bounds.height - 0.5, width: bounds.width - .contentPadding, height: 0.5)
    invalidateIntrinsicContentSize()
  }
  
  func layoutLeftLabel() {
    let maxWidth = contentView.frame.width
    let leftLabelFitSize = leftLabel.sizeThatFits(.zero)
    leftLabel.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: min(leftLabelFitSize.width, maxWidth), height: leftLabelFitSize.height))
  }
  
  func layoutRight() {
    let topLabelFitSize = rightTopLabel.sizeThatFits(.zero)
    let bottomLabelFitSize = rightBottomLabel.sizeThatFits(.zero)
    let maxLabelWidth = max(topLabelFitSize.width, bottomLabelFitSize.width)
    let maxRightWidth = max(maxLabelWidth, .shimmerWidth)
    let availableWidth = contentView.frame.width - leftLabel.frame.width
    
    let rightOriginY: CGFloat
    let rightOriginX: CGFloat
    let rightWidth: CGFloat
    if availableWidth > maxRightWidth {
      rightOriginY = 0
      rightOriginX = leftLabel.frame.maxX
      rightWidth = availableWidth
    } else {
      rightOriginY = leftLabel.frame.maxY
      rightOriginX = 0
      rightWidth = contentView.frame.width
    }
    
    let topHeight: CGFloat = rightTopShimmerView.isHidden ? topLabelFitSize.height : CGFloat.rightTopShimmerHeight
    let bottomHeight = rightBottomShimmerView.isHidden ? bottomLabelFitSize.height : CGFloat.rightBottomShimmerheight
    
    rightContentView.frame = CGRect(
      origin: CGPoint(x: rightOriginX, y: rightOriginY), 
      size: CGSize(width: rightWidth, height: topHeight + bottomHeight)
    )
    
    let topLabelWidth = min(rightWidth, topLabelFitSize.width)
    rightTopLabel.frame = CGRect(
      origin: CGPoint(x: rightWidth - topLabelWidth, y: 0),
      size: CGSize(width: topLabelWidth, height: topLabelFitSize.height)
    )
    
    rightTopShimmerView.frame = CGRect(
      origin: CGPoint(x: rightWidth - .shimmerWidth, y: 0),
      size: CGSize(width: .shimmerWidth, height: CGFloat.rightTopShimmerHeight)
    )
    
    let bottomLabelWidth = min(rightWidth, bottomLabelFitSize.width)
    rightBottomLabel.frame = CGRect(
      origin: CGPoint(x: rightWidth - bottomLabelWidth, y: max(rightTopLabel.frame.maxY, rightTopShimmerView.frame.maxY)),
      size: CGSize(width: bottomLabelWidth, height: bottomLabelFitSize.height)
    )
    
    rightBottomShimmerView.frame = CGRect(
      origin: CGPoint(x: rightWidth - .shimmerWidth, y: max(rightTopLabel.frame.maxY, rightTopShimmerView.frame.maxY)),
      size: CGSize(width: .shimmerWidth, height: CGFloat.rightBottomShimmerheight)
    )
  }
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: rightContentView.frame.maxY + .contentPadding*2)
  }
}

private extension ModalContentListItemView {
  func setup() {
    didUpdateIsHighlighted()
    rightTopLabel.numberOfLines = 0
    
    contentView.isUserInteractionEnabled = false
    
    addSubview(contentView)
    addSubview(separatorView)
    contentView.addSubview(leftLabel)
    contentView.addSubview(rightContentView)
    rightContentView.addSubview(rightTopLabel)
    rightContentView.addSubview(rightTopShimmerView)
    rightContentView.addSubview(rightBottomLabel)
    rightContentView.addSubview(rightBottomShimmerView)
  }
  
  func didUpdateIsHighlighted() {
    backgroundColor = isHighlighted ? .Background.highlighted : .Background.content
    separatorView.isHidden = isSeparatorHidden || isHighlighted
  }
}

private extension CGFloat {
  static let leftRightSpacing: CGFloat = 18
  static let rightTopShimmerHeight: CGFloat = 22
  static let rightBottomShimmerheight: CGFloat = 22
  static let shimmerWidth: CGFloat = 50
  static let contentPadding: CGFloat = 16
}

