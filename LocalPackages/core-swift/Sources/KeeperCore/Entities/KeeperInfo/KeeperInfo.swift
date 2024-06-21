import Foundation

/// Represents the entire state of the application install
public struct KeeperInfo: Codable, Equatable {
  /// Keeper contains multiple wallets
  public let wallets: [Wallet]
  
  /// Currently selected wallet
  public let currentWallet: Wallet
  
  /// Currently selected currency
  public let currency: Currency
  
  /// Common pin/faceid settings
  let securitySettings: SecuritySettings
  
  let isSetupFinished: Bool
  
  ///
  let assetsPolicy: AssetsPolicy
  let appCollection: AppCollection
}
