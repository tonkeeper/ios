import UIKit

public final class TKUIListItemImageAccessoryView: UIView, TKConfigurableView {
  let imageView = UIImageView()
  private var padding: UIEdgeInsets = .zero

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Configuration: Hashable {
    public let image: UIImage
    public let tintColor: UIColor
    public let padding: UIEdgeInsets
    
    public init(image: UIImage, tintColor: UIColor, padding: UIEdgeInsets) {
      self.image = image
      self.tintColor = tintColor
      self.padding = padding
    }
  }
  
  public func configure(configuration: Configuration) {
    imageView.image = configuration.image
    imageView.tintColor = configuration.tintColor
    padding = configuration.padding
    setNeedsLayout()
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let sizeThatFits = imageView.sizeThatFits(size)
    let width = sizeThatFits.width + padding.left + padding.right
    let height = sizeThatFits.height + padding.top + padding.bottom
    return CGSize(width: width, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    let sizeThatFits = imageView.sizeThatFits(.zero)
    let frame = CGRect(
      x: padding.left,
      y: padding.top,
      width: sizeThatFits.width,
      height: sizeThatFits.height
    )
    imageView.frame = frame
  }
}

private extension TKUIListItemImageAccessoryView {
  func setup() {
    addSubview(imageView)
  }
}

extension UIEdgeInsets: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.left)
    hasher.combine(self.bottom)
    hasher.combine(self.right)
    hasher.combine(self.top)
  }
}
