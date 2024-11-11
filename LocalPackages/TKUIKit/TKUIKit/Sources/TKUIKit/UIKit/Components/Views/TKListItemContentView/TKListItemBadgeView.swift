import UIKit

public final class TKListItemBadgeView: UIView {
    
  public enum Configuration: Hashable {
    case imageView(TKImageView.Model)
    
    public static var `default`: Configuration {
      Configuration.imageView(TKImageView.Model(image: nil))
    }
  }
  
  public var configuration = Configuration.default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  public let iconView = TKImageView()
  public let customViewContainer = UIView()
  
  private var customView: UIView?
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let contentViewFrame = CGRect(origin: CGPoint(x: .padding, y: .padding),
                                  size: CGSize(width: .side, height: .side))
    iconView.frame = contentViewFrame
    customViewContainer.frame = contentViewFrame
    customView?.frame = customViewContainer.bounds
    
    layer.cornerRadius = bounds.width/2
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: .side + .padding * 2, height: .side + .padding * 2)
  }
  
  private func setup() {
    backgroundColor = .Background.content
    
    addSubview(iconView)
    addSubview(customViewContainer)
    
    layer.masksToBounds = true
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    switch configuration {
    case .imageView(let configuration):
      iconView.isHidden = false
      iconView.configure(model: configuration)
      customViewContainer.isHidden = true
      customView?.removeFromSuperview()
    }
  }
}

private extension CGFloat {
  static let side: CGFloat = 18
  static let padding: CGFloat = 2
}
