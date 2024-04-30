import Foundation

/// Represents the entire state of the application install
public struct KeeperInfo: Codable {
  /// Keeper contains multiple wallets
  let wallets: [Wallet]
  
  /// Currently selected wallet
  let currentWallet: Wallet
  
  /// Currently selected currency
  let currency: Currency
  
  /// Common pin/faceid settings
  let securitySettings: SecuritySettings
  
  let isSetupFinished: Bool
  
  ///
  let assetsPolicy: AssetsPolicy
  let appCollection: AppCollection
}
