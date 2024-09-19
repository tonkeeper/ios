import UIKit
import TKUIKit
import TKCore
import KeeperCore

extension TKListItemIconView.Configuration {
  static func configuration(jettonInfo: JettonInfo) -> TKListItemIconView.Configuration {
    return TKListItemIconView.Configuration(
      content: .image(TKImageView.Model(image: .urlImage(jettonInfo.imageURL), size: .size(CGSize(width: 44, height: 44)), corners: .circle)),
      alignment: .center,
      cornerRadius: 22,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44)
    )
  }
}
