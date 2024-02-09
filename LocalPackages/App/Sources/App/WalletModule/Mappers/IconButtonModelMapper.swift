import UIKit
import TKUIKit
import KeeperCore

struct IconButtonModelMapper {
  func mapButton(model: KeeperCore.IconButton) -> TKUIIconButton.Model {
    return TKUIIconButton.Model(
      image: model.image,
      title: model.title
    )
  }
}

extension KeeperCore.IconButton {
  var image: UIImage {
    switch self {
    case .buySell: return .TKUIKit.Icons.Size28.usd
    case .receive: return .TKUIKit.Icons.Size28.arrowDownOutline
    case .scan: return .TKUIKit.Icons.Size28.qrViewFinderThin
    case .send: return .TKUIKit.Icons.Size28.arrowUpOutline
    case .stake: return .TKUIKit.Icons.Size28.stakingOutline
    case .swap: return .TKUIKit.Icons.Size28.swapHorizontalOutline
    }
  }
  
  var title: String {
    switch self {
    case .buySell: return "Buy or Sell"
    case .receive: return "Receive"
    case .scan: return "Scan"
    case .send: return "Send"
    case .stake: return "Stake"
    case .swap: return "Swap"
    }
  }
}
