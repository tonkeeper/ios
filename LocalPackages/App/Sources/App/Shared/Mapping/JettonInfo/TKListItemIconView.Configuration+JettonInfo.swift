import UIKit
import TKUIKit
import TKCore
import KeeperCore

extension TKListItemIconViewV2.Configuration {
  static func configuration(jettonInfo: JettonInfo) -> TKListItemIconViewV2.Configuration {
    return TKListItemIconViewV2.Configuration(
      content: .image(TKImageView.Model(image: .urlImage(jettonInfo.imageURL), size: .size(CGSize(width: 44, height: 44)), corners: .circle)),
      alignment: .center,
      cornerRadius: 22,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44)
    )
  }
}
