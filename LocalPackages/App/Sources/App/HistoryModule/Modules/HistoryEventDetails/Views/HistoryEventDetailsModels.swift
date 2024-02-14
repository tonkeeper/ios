import UIKit
import KeeperCore

enum Image: Equatable, Hashable {
  case url(URL?)
  case image(UIImage?, tinColor: UIColor?, backgroundColor: UIColor?)
}

extension Image {
  static func with(image: KeeperCore.TokenImage) -> Image {
    switch image {
    case .ton: return .image(.Icons.tonIcon, tinColor: .Icon.primary, backgroundColor: .Constant.tonBlue)
    case let .url(url): return .url(url)
    }
  }
}
