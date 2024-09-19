import UIKit

final class TKCollectionViewListCellAccessoryContainerView: UIView {
  
  var accessoryViews = [UIView]() {
    didSet {
      oldValue.forEach { $0.removeFromSuperview() }
      accessoryViews.forEach { addSubview($0) }
      setNeedsLayout()
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    var x: CGFloat = 0
    for view in accessoryViews {
      let sizeThatFits = view.sizeThatFits(bounds.size)
      let frame = CGRect(x: x, y: bounds.height/2 - sizeThatFits.height/2, width: sizeThatFits.width, height: sizeThatFits.height)
      view.frame = frame
      x = frame.maxX
    }
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var width: CGFloat = 0
    var height: CGFloat = 0
    for view in accessoryViews {
      let sizeThatFits = view.sizeThatFits(size)
      width += sizeThatFits.width
      height = sizeThatFits.height > height ? sizeThatFits.height : height
    }
    return CGSize(width: width, height: height)
  }
}
