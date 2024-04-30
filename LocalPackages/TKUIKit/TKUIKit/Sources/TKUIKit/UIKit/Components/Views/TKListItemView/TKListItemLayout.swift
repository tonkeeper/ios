import UIKit

public struct TKListItemLayout {
  let iconView: UIView?
  let contentView: UIView
  let valueView: UIView?
  
  public init(iconView: UIView?, 
              contentView: UIView,
              valueView: UIView?) {
    self.iconView = iconView
    self.contentView = contentView
    self.valueView = valueView
  }
  
  public func layouSubviews(bounds: CGRect) {
    var originX: CGFloat = 0
    var estimatedWidth = bounds.width
    
    if let iconView = iconView {
      let iconViewFittingSize = iconView.sizeThatFits(bounds.size)
      iconView.frame = CGRect(
        origin: CGPoint(
          x: originX,
          y: 0
        ),
        size: CGSize(
          width: iconViewFittingSize.width,
          height: bounds.height
        )
      )
      
      estimatedWidth -= iconViewFittingSize.width + .iconViewRightInset
      originX = iconView.frame.maxX + .iconViewRightInset
    }
    
    if let valueView = valueView {
      let valueViewFittingSize = valueView.sizeThatFits(
        CGSize(
          width: estimatedWidth,
          height: 0
        )
      )
      let valueViewSize = CGSize(
        width: min(estimatedWidth, valueViewFittingSize.width),
        height: valueViewFittingSize.height
      )
      valueView.frame = CGRect(
        origin: CGPoint(
          x: bounds.width - valueViewSize.width,
          y: bounds.height/2 - valueViewSize.height/2
        ),
        size: valueViewSize
      )
      estimatedWidth -= valueViewSize.width
      if valueViewSize.width > 0 {
        estimatedWidth -= .valueViewLeftInset
      }
    }
    
    let contentViewSize = CGSize(width: estimatedWidth, height: bounds.height)
    contentView.frame = CGRect(origin: CGPoint(x: originX, y: 0),
                               size: contentViewSize)
  }
  
  public func calculateSize(targetSize: CGSize) -> CGSize {
    var estimatedWidth = targetSize.width
    
    let iconViewFittingSize: CGSize = iconView?.sizeThatFits(targetSize) ?? .zero
    let iconRightInset: CGFloat = iconView == nil ? 0 : .iconViewRightInset
    estimatedWidth -= iconViewFittingSize.width + iconRightInset
    
    let valueViewFittingSize = valueView?.sizeThatFits(CGSize(width: estimatedWidth, height: targetSize.height)) ?? .zero
    let valueViewLeftInset: CGFloat = valueView == nil ? 0 : .valueViewLeftInset
    estimatedWidth -= valueViewFittingSize.width + valueViewLeftInset
    
    let contentViewFittingSize = contentView.sizeThatFits(
      CGSize(
        width: estimatedWidth,
        height: targetSize.height
      )
    )
    
    let resultWidth = targetSize.width
    let resultHeight = [iconViewFittingSize.height, valueViewFittingSize.height, contentViewFittingSize.height].max() ?? 0
    
    return CGSize(width: resultWidth, height: resultHeight)
  }
}

private extension CGFloat {
  static let iconViewRightInset: CGFloat = 16
  static let valueViewLeftInset: CGFloat = 16
}
