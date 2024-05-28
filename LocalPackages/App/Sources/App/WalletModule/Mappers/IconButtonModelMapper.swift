import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

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
    case .deposit: return .TKUIKit.Icons.Size28.plusOutline
    case .withdraw: return .TKUIKit.Icons.Size28.minusOutline
    }
  }
  
  var title: String {
    switch self {
    case .buySell: return TKLocales.WalletButtons.buy
    case .receive: return TKLocales.WalletButtons.receive
    case .scan: return TKLocales.WalletButtons.scan
    case .send: return TKLocales.WalletButtons.send
    case .stake: return TKLocales.WalletButtons.stake
    case .swap: return TKLocales.WalletButtons.swap
    case .deposit: return TKLocales.WalletButtons.stake
    case .withdraw: return TKLocales.WalletButtons.unstake
    }
  }
}
