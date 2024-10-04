import UIKit
import TKUIKit
import KeeperCore

extension TKUIListItemContentLeftItem.Configuration {
  static func tonConfiguration(subtitle: NSAttributedString?) -> TKUIListItemContentLeftItem.Configuration {
    
    let title = TonInfo.symbol.withTextStyle(
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
}
