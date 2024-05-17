import UIKit

public final class TKUIListItemContentView: UIView, TKConfigurableView {
  
  let leftItem = TKUIListItemContentLeftItem()
  let rightItem = TKUIListItemContentRightItem()
  private var isVerticalCenter: Bool = true
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    var width = size.width
    var rightItemHeight: CGFloat = 0
    if !rightItem.isHidden {
      let rightItemSize = rightItem.sizeThatFits(
        CGSize(width: size.width,
               height: size.height)
      )
      width -= rightItemSize.width
      rightItemHeight = rightItemSize.height
    }
    let leftItemSize = leftItem.sizeThatFits(
      CGSize(
        width: width,
        height: size.height
      )
    )
    
    let height = [rightItemHeight, leftItemSize.height].max() ?? 0
    return CGSize(width: size.width,
                  height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    var width = bounds.width
    
    if !rightItem.isHidden {
      let rightItemSizeToFit = rightItem.sizeThatFits(CGSize(width: bounds.width, height: bounds.height))
      let rightItemSize = CGSize(
        width: rightItemSizeToFit.width,
        height: isVerticalCenter ? rightItemSizeToFit.height : bounds.height
      )
      let rightItemFrame = CGRect(origin: CGPoint(x: bounds.width - rightItemSize.width, y: 0),
                                  size: rightItemSize)
      width -= rightItemSize.width
      rightItem.frame = rightItemFrame
    }
    
    let leftItemSizeToFit = leftItem.sizeThatFits(
      CGSize(
        width: width,
        height: bounds.height
      )
    )
    let leftItemSize = CGSize(
      width: leftItemSizeToFit.width,
      height: isVerticalCenter ? leftItemSizeToFit.height : bounds.height
    )
    let leftItemFrame = CGRect(origin: CGPoint(x: 0, y: bounds.height/2 - leftItemSize.height/2), size: leftItemSize)
    
    leftItem.frame = leftItemFrame
  }
  
  public struct Configuration: Hashable {
    public let leftItemConfiguration: TKUIListItemContentLeftItem.Configuration?
    public let rightItemConfiguration: TKUIListItemContentRightItem.Configuration?
    public let isVerticalCenter: Bool
    
    public init(leftItemConfiguration: TKUIListItemContentLeftItem.Configuration?,
                rightItemConfiguration: TKUIListItemContentRightItem.Configuration?,
                isVerticalCenter: Bool = true) {
      self.leftItemConfiguration = leftItemConfiguration
      self.rightItemConfiguration = rightItemConfiguration
      self.isVerticalCenter = isVerticalCenter
    }
  }
  
  public func configure(configuration: Configuration) {
    if let leftItemConfiguration = configuration.leftItemConfiguration {
      leftItem.configure(configuration: leftItemConfiguration)
      leftItem.isHidden = false
    } else {
      leftItem.isHidden = true
    }
    if let rightItemConfiguration = configuration.rightItemConfiguration {
      rightItem.configure(configuration: rightItemConfiguration)
      rightItem.isHidden = false
    } else {
      rightItem.isHidden = true
    }
    self.isVerticalCenter = configuration.isVerticalCenter
    setNeedsLayout()
  }
}

private extension TKUIListItemContentView {
  func setup() {
    addSubview(leftItem)
    addSubview(rightItem)
  }
}
