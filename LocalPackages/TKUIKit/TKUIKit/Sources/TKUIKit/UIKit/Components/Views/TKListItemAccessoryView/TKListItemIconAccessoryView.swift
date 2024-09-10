import UIKit

public final class TKListItemIconAccessoryView: UIControl {
  
  public struct Configuration {
    public let icon: UIImage
    public let tintColor: UIColor?
    public let action: (() -> Void)?
    
    public init(icon: UIImage,
                tintColor: UIColor? = nil,
                action: (() -> Void)? = nil) {
      self.icon = icon
      self.tintColor = tintColor
      self.action = action
    }
    
    public static var `default` = Configuration(icon: .TKUIKit.Icons.Size16.chevronRight, action: nil)
    
    public static var chevron = Configuration(icon: .TKUIKit.Icons.Size16.chevronRight,
                                              tintColor: .Icon.tertiary,
                                              action: nil)
  }
  
  public var configuration: Configuration = .default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  public override var isHighlighted: Bool {
    didSet {
      guard configuration.action != nil else { return }
      alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  private let imageView = UIImageView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let sizeThatFits = imageView.sizeThatFits(.zero)
    imageView.frame = CGRect(x: 0, y: 0, width: sizeThatFits.width, height: bounds.height)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let imageSizeThatFits = imageView.sizeThatFits(.zero)
    return CGSize(width: imageSizeThatFits.width + 16, height: imageSizeThatFits.height)
  }
  
  public override var intrinsicContentSize: CGSize {
    sizeThatFits(.init(width: bounds.width, height: 0))
  }
  
  private func setup() {
    imageView.contentMode = .center
    
    addSubview(imageView)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.configuration.action?()
    }), for: .touchUpInside)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    imageView.image = configuration.icon
    imageView.tintColor = configuration.tintColor
  }
}
