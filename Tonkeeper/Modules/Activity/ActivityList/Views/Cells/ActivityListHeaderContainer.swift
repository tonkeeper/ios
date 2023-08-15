//
//  ActivityListHeaderContainer.swift
//  Tonkeeper
//
//  Created by Grigory on 15.8.23..
//

import UIKit

final class ActivityListHeaderContainer: UICollectionReusableView, Reusable {
  
  private var contentView: UIView?
  
  override func preferredLayoutAttributesFitting(
    _ layoutAttributes: UICollectionViewLayoutAttributes
  ) -> UICollectionViewLayoutAttributes {
    let height: CGFloat
    if let contentView = contentView {
      height = contentView.systemLayoutSizeFitting(
        layoutAttributes.size,
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .defaultLow).height
    } else {
      height = 0
    }
    
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size.height = height
    return modifiedAttributes
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    contentView?.frame = bounds
  }
  
  func setContentView(_ contentView: UIView?) {
    self.contentView?.removeFromSuperview()
    self.contentView = contentView
    
    if let contentView = contentView {
      addSubview(contentView)
    }
  }
}
