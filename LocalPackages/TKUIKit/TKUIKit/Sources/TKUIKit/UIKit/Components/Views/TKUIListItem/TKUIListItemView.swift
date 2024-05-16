import UIKit

public final class TKUIListItemView: UIView, TKConfigurableView, ReusableView {
  
  let iconView = TKUIListItemIconView()
  let contentView = TKUIListItemContentView()
  let accessoryView = TKUIListItemAccessoryView()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func prepareForReuse() {
    iconView.prepareForReuse()
  }
  
  public struct Configuration: Hashable {
    let iconConfiguration: TKUIListItemIconView.Configuration
    let contentConfiguration: TKUIListItemContentView.Configuration
    let accessoryConfiguration: TKUIListItemAccessoryView.Configuration
    
    public init(iconConfiguration: TKUIListItemIconView.Configuration = TKUIListItemIconView.Configuration(iconConfiguration: .none, alignment: .top),
                contentConfiguration: TKUIListItemContentView.Configuration,
                accessoryConfiguration: TKUIListItemAccessoryView.Configuration) {
      self.iconConfiguration = iconConfiguration
      self.contentConfiguration = contentConfiguration
      self.accessoryConfiguration = accessoryConfiguration
    }
  }
  
  public func configure(configuration: Configuration) {
    iconView.configure(configuration: configuration.iconConfiguration)
    contentView.configure(configuration: configuration.contentConfiguration)
    accessoryView.configure(configuration: configuration.accessoryConfiguration)
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let iconViewSizeThatFits = iconView.sizeThatFits(size)
    let accessoryViewSizeThatFits = accessoryView.sizeThatFits(
      size
    )
    var contentViewWidth = size.width
    if !iconViewSizeThatFits.width.isZero {
      contentViewWidth -= iconViewSizeThatFits.width + 16
    }
    if !accessoryViewSizeThatFits.width.isZero {
      contentViewWidth -= accessoryViewSizeThatFits.width + 16
    }
    
    let contentViewSizeThatFits = contentView.sizeThatFits(
      CGSize(
        width: contentViewWidth,
        height: size.height
      )
    )
    
    let height = max(iconViewSizeThatFits.height, contentViewSizeThatFits.height)
    
    return CGSize(width: size.width, height: height)
  }
  
  public override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    accessoryView.sizeToFit()
    accessoryView.frame.origin = CGPoint(
      x: bounds.width - accessoryView.frame.width,
      y: bounds.height/2 - accessoryView.frame.height/2
    )
    iconView.sizeToFit()
    iconView.frame.size = CGSize(width: iconView.bounds.width, height: bounds.height)
    iconView.frame.origin = CGPoint(
      x: 0,
      y: 0
    )
    
    var contentViewWidth = bounds.width
    var contentViewX: CGFloat = 0
    if !accessoryView.frame.width.isZero {
      contentViewWidth -= accessoryView.frame.width + 16
    }
    if !iconView.frame.width.isZero {
      contentViewWidth -= iconView.frame.width + 16
      contentViewX = iconView.frame.maxX + 16
    }
    
    contentView.frame = CGRect(x: contentViewX, y: 0, width: contentViewWidth, height: bounds.height)
  }
}

private extension TKUIListItemView {
  func setup() {
    addSubview(iconView)
    addSubview(contentView)
    addSubview(accessoryView)
  }
}
