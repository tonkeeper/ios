import UIKit
import KeeperCore

enum EnumImage: Equatable, Hashable {
  case url(URL?)
  case image(UIImage?, tinColor: UIColor?, backgroundColor: UIColor?)
}

extension EnumImage {
  static func with(image: KeeperCore.TokenImage) -> EnumImage {
    switch image {
    case .ton: return .image(.TKUIKit.Icons.Size44.tonCurrency, tinColor: .Icon.primary, backgroundColor: .Constant.tonBlue)
    case let .url(url): return .url(url)
    }
  }
}
