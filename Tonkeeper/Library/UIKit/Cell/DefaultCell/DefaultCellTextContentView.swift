//
//  DefaultCellTextContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class DefaultCellTextContentView: UIView, ConfigurableView, ContainerCollectionViewCellContent {

  let topLeftHorizontalStack = TopLeftHorizontalStack()
  let topRightLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.primary
    label.numberOfLines = 1
    label.textAlignment = .right
    return label
  }()
  let middleLeftHorizontalStack = MiddleLeftHorizontalStack()
  let middleRightLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .right
    return label
  }()
  let bottomLeftLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  let bottomRightLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .right
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    var topWidth = bounds.width
    var middleWidth = bounds.width
    var bottomWidth = bounds.width
    
    topRightLabel.sizeToFit()
    topWidth -= topRightLabel.frame.width + 8
    
    middleRightLabel.sizeToFit()
    middleWidth -= middleRightLabel.frame.width + 8
    
    bottomRightLabel.sizeToFit()
    bottomWidth -= bottomRightLabel.frame.width + 8
    
    topLeftHorizontalStack.sizeToFit()
    topLeftHorizontalStack.frame.size.width = min(topWidth, topLeftHorizontalStack.frame.width)
    topLeftHorizontalStack.frame.origin.x = 0
    topLeftHorizontalStack.frame.origin.y = 0
    
    middleLeftHorizontalStack.sizeToFit()
    middleLeftHorizontalStack.frame.size.width = min(middleWidth, middleLeftHorizontalStack.frame.size.width)
    middleLeftHorizontalStack.frame.origin.x = 0
    middleLeftHorizontalStack.frame.origin.y = topLeftHorizontalStack.frame.maxY
    middleWidth -= middleLeftHorizontalStack.frame.width
    
    bottomLeftLabel.sizeToFit()
    bottomLeftLabel.frame.size.width = min(bottomWidth, bottomLeftLabel.frame.size.width)
    bottomLeftLabel.frame.origin.x = 0
    bottomLeftLabel.frame.origin.y = middleLeftHorizontalStack.frame.height > 0 ? middleLeftHorizontalStack.frame.maxY : topLeftHorizontalStack.frame.maxY
    bottomWidth -= bottomLeftLabel.frame.width
    
    middleRightLabel.frame.origin.x = bounds.width - middleRightLabel.frame.width
    middleRightLabel.frame.origin.y = middleLeftHorizontalStack.frame.origin.y
    
    bottomRightLabel.frame.origin.x = bounds.width -  bottomRightLabel.frame.width
    bottomRightLabel.frame.origin.y = bottomLeftLabel.frame.origin.y
    
    let topRightLabelHeight: CGFloat = {
      var height = bounds.height
      if bottomRightLabel.frame.height > 0 || bottomWidth < topRightLabel.frame.width {
        height = bounds.height - (bounds.height - bottomRightLabel.frame.origin.y)
      }
      if middleRightLabel.frame.height > 0 || middleWidth < topRightLabel.frame.width {
        height = bounds.height - (bounds.height - middleRightLabel.frame.origin.y)
      }
      return height
    }()
    
    topRightLabel.frame.origin.x = bounds.width - topRightLabel.frame.width
    topRightLabel.frame.origin.y = 0
    topRightLabel.frame.size.height = topRightLabelHeight
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let leftHeight =
    topLeftHorizontalStack.sizeThatFits(.zero).height +
    middleLeftHorizontalStack.sizeThatFits(.zero).height +
    bottomLeftLabel.sizeThatFits(.zero).height
    
    let rightHeight =
    topRightLabel.sizeThatFits(.zero).height +
    middleRightLabel.sizeThatFits(.zero).height +
    bottomRightLabel.sizeThatFits(.zero).height
    
    return .init(width: size.width, height: max(leftHeight, rightHeight))
  }
  
  func configure(model: Model) {
    topLeftHorizontalStack.leftLabel.attributedText = model.leftTopTitle
    topLeftHorizontalStack.rightLabel.attributedText = model.leftTopRightTitle
    
    middleLeftHorizontalStack.leftLabel.attributedText = model.leftMiddleTitle
    middleLeftHorizontalStack.rightLabel.attributedText = model.leftMiddleRightTitle
    
    bottomLeftLabel.attributedText = model.leftBottomTitle
    
    topRightLabel.attributedText = model.rightTopTitle
    
    middleRightLabel.attributedText = model.rightMiddleTitle
    
    bottomRightLabel.attributedText = model.rightBottomTitle
    
    setNeedsLayout()
  }
  
  func prepareForReuse() {
    topLeftHorizontalStack.leftLabel.attributedText = nil
    topLeftHorizontalStack.rightLabel.attributedText = nil
    
    middleLeftHorizontalStack.leftLabel.attributedText = nil
    middleLeftHorizontalStack.rightLabel.attributedText = nil
    
    bottomLeftLabel.attributedText = nil
    
    topRightLabel.attributedText = nil
    
    middleRightLabel.attributedText = nil
    
    bottomRightLabel.attributedText = nil
  }
}

private extension DefaultCellTextContentView {
  func setup() {
    addSubview(topRightLabel)
    addSubview(topLeftHorizontalStack)
    addSubview(middleLeftHorizontalStack)
    addSubview(middleRightLabel)
    addSubview(bottomLeftLabel)
    addSubview(bottomRightLabel)
  }
}

final class TopLeftHorizontalStack: UIView {
  let leftLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.primary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  
  let rightLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.tertiary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()

    var width: CGFloat = bounds.width
    
    rightLabel.sizeToFit()
    width -= rightLabel.frame.width + 4
    
    leftLabel.sizeToFit()
    leftLabel.frame.size.width = width
    
    
    leftLabel.frame.origin.x = 0
    leftLabel.frame.origin.y = bounds.height / 2 - leftLabel.frame.height/2
    
    rightLabel.frame.origin.x = leftLabel.frame.maxX + 4
    rightLabel.frame.origin.y = bounds.height / 2 - rightLabel.frame.height/2
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    leftLabel.sizeToFit()
    rightLabel.sizeToFit()
    let width = leftLabel.frame.width + rightLabel.frame.width + 4
    let height = max(leftLabel.frame.height, rightLabel.frame.height)
    return .init(width: width, height: height)
  }
  
  private func setup() {
    addSubview(leftLabel)
    addSubview(rightLabel)
  }
}

final class MiddleLeftHorizontalStack: UIView {
  let leftLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  
  let rightLabel: UILabel = {
    let label = UILabel()
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    leftLabel.sizeToFit()
    rightLabel.sizeToFit()
    
    leftLabel.frame.origin.x = 0
    leftLabel.frame.origin.y = bounds.height / 2 - leftLabel.frame.height/2
    
    rightLabel.frame.origin.x = leftLabel.frame.maxX + 4
    rightLabel.frame.origin.y = bounds.height / 2 - rightLabel.frame.height/2
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    leftLabel.sizeToFit()
    rightLabel.sizeToFit()
    let width = leftLabel.frame.width + rightLabel.frame.width + 4
    let height = max(leftLabel.frame.height, rightLabel.frame.height)
    return .init(width: width, height: height)
  }
  
  private func setup() {
    addSubview(leftLabel)
    addSubview(rightLabel)
  }
}
