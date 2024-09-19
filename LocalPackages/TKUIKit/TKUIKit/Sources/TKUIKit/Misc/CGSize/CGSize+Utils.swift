import UIKit

public extension CGSize {
  func inset(by insets: UIEdgeInsets) -> CGSize {
    CGSize(width: width - insets.left - insets.right, height: height - insets.top - insets.bottom)
  }
  
  func padding(by paddings: UIEdgeInsets) -> CGSize {
    CGSize(width: width + paddings.left + paddings.right, height: height + paddings.top + paddings.bottom)
  }
}
