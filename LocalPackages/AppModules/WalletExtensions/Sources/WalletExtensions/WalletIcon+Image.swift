import UIKit
import TKUIKit
import KeeperCore

public extension WalletIcon.Image {
  var image: UIImage? {
    switch self {
    case .wallet:
      return .TKUIKit.Icons.WalletIcons.wallet
    case .leaf:
      return .TKUIKit.Icons.WalletIcons.leaf
    case .lock:
      return .TKUIKit.Icons.WalletIcons.lock
    case .key:
      return .TKUIKit.Icons.WalletIcons.key
    case .inbox:
      return .TKUIKit.Icons.WalletIcons.inbox
    case .snowflake:
      return .TKUIKit.Icons.WalletIcons.snowflake
    case .sparkles:
      return .TKUIKit.Icons.WalletIcons.sparkles
    case .sun:
      return .TKUIKit.Icons.WalletIcons.sun
    case .hare:
      return .TKUIKit.Icons.WalletIcons.hare
    case .flash:
      return .TKUIKit.Icons.WalletIcons.flash
    case .bankCard:
      return .TKUIKit.Icons.WalletIcons.bankCard
    case .gear:
      return .TKUIKit.Icons.WalletIcons.gear
    case .handRaised:
      return .TKUIKit.Icons.WalletIcons.handRaised
    case .magnifyingGlassCircle:
      return .TKUIKit.Icons.WalletIcons.magnifyingGlassCircle
    case .flashCircle:
      return .TKUIKit.Icons.WalletIcons.flashCircle
    case .dollarCircle:
      return .TKUIKit.Icons.WalletIcons.dollarCircle
    case .euroCircle:
      return .TKUIKit.Icons.WalletIcons.euroCircle
    case .sterlingCircle:
      return .TKUIKit.Icons.WalletIcons.sterlingCircle
    case .yuanCircle:
      return .TKUIKit.Icons.WalletIcons.chineseYuanCircle
    case .rubleCircle:
      return .TKUIKit.Icons.WalletIcons.rubleCircle
    case .indianRupeeCircle:
      return .TKUIKit.Icons.WalletIcons.indianRupeeCircle
    }
  }
}
