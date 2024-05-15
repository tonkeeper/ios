import Foundation
import TKLocalize

public struct WalletModel: Equatable {
  public enum WalletType {
    case regular
    case watchOnly
    case external
  }
  
  public let identifier: String
  public let label: String
  public let tag: String?
  public let emoji: String
  public let tintColor: WalletTintColor
  public let walletType: WalletType
  public let isTestnet: Bool
  
  public var emojiLabel: String {
    "\(emoji) \(label)"
  }
  
  public static func == (lhs: WalletModel, rhs: WalletModel) -> Bool {
    lhs.identifier == rhs.identifier
  }
}

extension Wallet {
  public var model: WalletModel {
    
    let walletType: WalletModel.WalletType
    switch self.identity.kind {
    case .Regular:
      walletType = .regular
    case .Lockup:
      fatalError("")
    case .Watchonly:
      walletType = .watchOnly
    case .External:
      walletType = .external
    }

    return WalletModel(
      identifier: id,
      label: metaData.label,
      tag: tag,
      emoji: metaData.emoji,
      tintColor: metaData.tintColor,
      walletType: walletType,
      isTestnet: identity.network == .testnet
    )
  }
}
