import UIKit
import TKUIKit
import KeeperCore

extension TokenPickerButton.Configuration {
  static func createConfiguration(token: Token) -> Self {
    let title: String
    let image: TKImage
    switch token {
    case .ton:
      title = TonInfo.symbol
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .jetton(let item):
      title = item.jettonInfo.symbol ?? ""
      image = .urlImage(item.jettonInfo.imageURL)
    }
    
    return TokenPickerButton.Configuration(
      name: title,
      image: image
    )
  }
}
