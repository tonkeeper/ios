import UIKit
import TKUIKit
import KeeperCore

extension Wallet {
  var listItemIconViewConfiguration: TKListItemIconViewV2.Configuration {
    let content: TKListItemIconViewV2.Configuration.Content
    switch self.icon {
    case .emoji(let emoji):
      content = .text(TKListItemIconViewV2.Configuration.TextContent(text: emoji))
    case .icon(let image):
      content = .image(TKImageView.Model(image: .image(image.image), tintColor: .white, size: .size(CGSize(width: 24, height: 24))))
    }
    let configuration = TKListItemIconViewV2.Configuration(
      content: content,
      alignment: .top,
      cornerRadius: 22,
      backgroundColor: tintColor.uiColor,
      size: CGSize(width: 44, height: 44)
    )
    return configuration
  }
}
