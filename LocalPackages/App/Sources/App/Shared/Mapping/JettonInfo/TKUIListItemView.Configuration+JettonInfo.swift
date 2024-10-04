import UIKit
import TKUIKit
import KeeperCore

extension TKUIListItemContentLeftItem.Configuration {
  static func configuration(jettonInfo: JettonInfo,
                            subtitle: NSAttributedString?) -> TKUIListItemContentLeftItem.Configuration {
    
    let title = (jettonInfo.symbol ?? jettonInfo.name).withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    var tagViewModel: TKUITagView.Configuration?
    if let tag = jettonInfo.tag {
      tagViewModel = TKUITagView.Configuration(
        text: tag,
        textColor: .Text.secondary,
        backgroundColor: .Background.contentTint
      )
    }
    
    return TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: tagViewModel,
      subtitle: subtitle,
      description: nil
    )
  }
}
