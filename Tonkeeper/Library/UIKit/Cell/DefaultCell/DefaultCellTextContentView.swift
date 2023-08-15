//
//  DefaultCellTextContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class DefaultCellTextContentView: UIView, ConfigurableView, ContainerCollectionViewCellContent {
  
  let amountView = AmountVerticalContainer()
  let topLeftDescriptionView = TopLeftDescriptionHorizontalContainer()
  let titleLabel = UILabel()
  let topRightDescriptionLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let titleSizeThatFits = titleLabel.sizeThatFits(.zero)
    let titleSize = CGSize(width: min(bounds.width, titleSizeThatFits.width),
                           height: titleSizeThatFits.height)
    let titleFrame = CGRect(origin: CGPoint(x: 0, y: 0),
                            size: titleSize)
    
    let amountSize = amountView.sizeThatFits(
      CGSize(width: bounds.width - titleSize.width,
             height: 0)
    )
    var amountFrame = CGRect(
      origin: .init(x: bounds.width - amountSize.width, y: 0),
      size: amountSize
    )
    
    let topRightDescriptionSize = topRightDescriptionLabel.sizeThatFits(.zero)
    let topRightDescriptionFrame = CGRect(
      origin: .init(x: bounds.width - topRightDescriptionSize.width, y: amountFrame.maxY),
      size: topRightDescriptionSize
    )
    
    let topLeftAvailableWidth: CGFloat
    if amountFrame.maxY <= titleFrame.maxY {
      topLeftAvailableWidth = bounds.width - topRightDescriptionFrame.width - 8
    } else {
      topLeftAvailableWidth = bounds.width - amountFrame.width - 8
    }
    
    let topLeftDescriptionSize = topLeftDescriptionView.sizeThatFits(
      .init(width: topLeftAvailableWidth,
            height: 0)
    )
    let topLeftDescriptionFrame = CGRect(
      origin: .init(x: 0, y: titleFrame.maxY),
      size: topLeftDescriptionSize
    )
    
    if amountFrame.minX > topLeftDescriptionFrame.maxX, topRightDescriptionSize.height == 0 {
      amountFrame.origin.y = bounds.height/2 - amountFrame.height/2
    }

    titleLabel.frame = titleFrame
    amountView.frame = amountFrame
    topRightDescriptionLabel.frame = topRightDescriptionFrame
    topLeftDescriptionView.frame = topLeftDescriptionFrame
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let leftHeight = titleLabel.sizeThatFits(.zero).height
    + topLeftDescriptionView.sizeThatFits(.zero).height
    
    let rightHeight = amountView.sizeThatFits(.zero).height
    + topRightDescriptionLabel.sizeThatFits(.zero).height
  
    return CGSize(width: size.width, height: max(leftHeight, rightHeight))
  }
  
  func prepareForReuse() {
    titleLabel.text = nil
    amountView.topLabel.text = nil
    amountView.bottomLabel.text = nil
    topLeftDescriptionView.leftLabel.text = nil
    topLeftDescriptionView.rightLabel.text = nil
    topRightDescriptionLabel.text = nil
  }
}

private extension DefaultCellTextContentView {
  func setup() {
    addSubview(titleLabel)
    addSubview(amountView)
    addSubview(topLeftDescriptionView)
    addSubview(topRightDescriptionLabel)
  }
}

extension DefaultCellTextContentView {
  final class AmountVerticalContainer: UIView {
    let topLabel = UILabel()
    let bottomLabel = UILabel()
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
      super.layoutSubviews()
      let topLabelSize = topLabel.sizeThatFits(bounds.size)
      let bottomLabelSize = bottomLabel.sizeThatFits(bounds.size)
      let topLabelFrame = CGRect(
        x: 0,
        y: 0,
        width: bounds.width,
        height: topLabelSize.height
      )
      let bottomLabelFrame = CGRect(
        x: 0,
        y: topLabelFrame.maxY,
        width: bounds.width,
        height: bottomLabelSize.height
      )
      
      topLabel.frame = topLabelFrame
      bottomLabel.frame = bottomLabelFrame
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      let topLabelSize = topLabel.sizeThatFits(.zero)
      let bottomLabelSize = bottomLabel.sizeThatFits(.zero)
      let width = max(topLabelSize.width, bottomLabelSize.width)
      let height = topLabelSize.height + bottomLabelSize.height
      return CGSize(width: min(size.width, width), height: height)
    }
    
    private func setup() {
      addSubview(topLabel)
      addSubview(bottomLabel)
    }
  }
}

extension DefaultCellTextContentView {
  final class TopLeftDescriptionHorizontalContainer: UIView {
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
      
      let leftLabelSize = leftLabel.sizeThatFits(.zero)
      let rightLabelSize = rightLabel.sizeThatFits(.zero)
      
      let leftLabelFrame = CGRect(
        x: 0,
        y: bounds.height/2 - leftLabelSize.height/2,
        width: min(leftLabelSize.width, bounds.width),
        height: leftLabelSize.height
      )
      let rightLabelFrame = CGRect(
        x: leftLabel.frame.maxX + 6,
        y: bounds.height/2 - rightLabelSize.height/2,
        width: max(0, bounds.width - leftLabel.frame.width - 6),
        height: rightLabelSize.height
      )
      
      leftLabel.frame = leftLabelFrame
      rightLabel.frame = rightLabelFrame
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      let leftLabelSize = leftLabel.sizeThatFits(size)
      let rightLabelSize = rightLabel.sizeThatFits(size)
      let width = leftLabelSize.width + rightLabelSize.width + 6
      let height = max(leftLabelSize.height, rightLabelSize.height)
      return CGSize(width: min(width, size.width), height: height)
    }
    
    private func setup() {
      addSubview(leftLabel)
      addSubview(rightLabel)
    }
  }
}
