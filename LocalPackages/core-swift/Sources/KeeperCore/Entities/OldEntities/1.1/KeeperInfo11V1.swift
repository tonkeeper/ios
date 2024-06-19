import Foundation

extension Version11V1 {
  /// Represents the entire state of the application install
  public struct KeeperInfo: Codable {
    /// Keeper contains multiple wallets
    let wallets: [Version11V1.Wallet]
    
    /// Currently selected wallet
    let currentWallet: Version11V1.Wallet
    
    /// Currently selected currency
    let currency: Currency
    
    /// Common pin/faceid settings
    let securitySettings: SecuritySettings
    
    let isSetupFinished: Bool
    
    ///
    let assetsPolicy: AssetsPolicy
    let appCollection: AppCollection
  }
}
