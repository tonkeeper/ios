import UIKit

public extension UIScrollView {
  func scrollVerticallyToView(_ view: UIView, animated: Bool) {
    let viewFrame = view.frame
    let convertedViewFrame = convert(viewFrame, from: view.superview)
    let maxContentOffsetY: CGFloat = contentSize.height
    + contentInset.bottom
    - contentInset.top
    - bounds.height
    let contentOffsetY = min(maxContentOffsetY, convertedViewFrame.minY)
    setContentOffset(CGPoint(x: 0, y: contentOffsetY), animated: animated)
  }
}
