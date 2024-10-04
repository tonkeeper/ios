import UIKit
import TKUIKit
import KeeperCore

extension TKUIListItemContentLeftItem.Configuration {
  static func configuration(poolInfo: StackingPoolInfo?,
                            subtitle: NSAttributedString?) -> TKUIListItemContentLeftItem.Configuration {
    
    let title = poolInfo?.name.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    return TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: subtitle,
      description: nil
    )
  }
  
  static func configuration(title: String?,
                            poolInfo: StackingPoolInfo?) -> TKUIListItemContentLeftItem.Configuration {
    
    let title = title?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = poolInfo?.name.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    return TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: subtitle,
      description: nil
    )
  }
}
