import UIKit
import TKUIKit

final class ListItemAccessoryView: UIView, ConfigurableView {
  
  private var contentView: UIView?
  
  override func layoutSubviews() {
    super.layoutSubviews()
    contentView?.frame = bounds
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    contentView?.sizeThatFits(.zero) ?? .zero
  }
  
  // MARK: - ConfigurableView
  
  enum AccessoryType: Hashable {
    case disclosure
    case icon(UIImage?, UIColor)
  }
  
  func configure(model: AccessoryType) {
    contentView?.removeFromSuperview()
    let contentView: UIView
    switch model {
    case .disclosure:
      let imageView = UIImageView()
      imageView.tintColor = .Icon.tertiary
//      imageView.image = .TKUIKit.Icons.List.Accessory.disclosure
      contentView = imageView
    case let .icon(icon, tintColor):
      let imageView = UIImageView()
      imageView.tintColor = tintColor
      imageView.image = icon
      contentView = imageView
    }
    addSubview(contentView)
    self.contentView = contentView
    setNeedsLayout()
  }
}
