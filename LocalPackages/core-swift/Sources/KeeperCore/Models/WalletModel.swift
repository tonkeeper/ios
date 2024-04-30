import Foundation

public struct WalletModel: Equatable {
  public enum WalletType {
    case regular
    case watchOnly(tag: String)
  }
  
  public let identifier: String
  public let label: String
  public let tag: String?
  public let emoji: String
  public let tintColor: WalletTintColor
  public let walletType: WalletType
  
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
      walletType = .watchOnly(tag: "Watch only")
    case .External:
      fatalError("")
    }

    return WalletModel(
      identifier: id,
      label: metaData.label,
      tag: tag,
      emoji: metaData.emoji,
      tintColor: metaData.tintColor,
      walletType: walletType
    )
  }
}
