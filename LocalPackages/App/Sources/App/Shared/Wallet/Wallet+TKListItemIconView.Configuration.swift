import UIKit
import TKUIKit
import KeeperCore

extension Wallet {
  var listItemIconViewConfiguration: TKListItemIconView.Configuration {
    let content: TKListItemIconView.Configuration.Content
    switch self.icon {
    case .emoji(let emoji):
      content = .text(TKListItemIconView.Configuration.TextContent(text: emoji))
    case .icon(let image):
      content = .image(TKImageView.Model(image: .image(image.image), tintColor: .white, size: .size(CGSize(width: 24, height: 24))))
    }
    let configuration = TKListItemIconView.Configuration(
      content: content,
      alignment: .top,
      cornerRadius: 22,
      backgroundColor: tintColor.uiColor,
      size: CGSize(width: 44, height: 44)
    )
    return configuration
  }
}
