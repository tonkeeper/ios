import Foundation

/// Represents the entire state of the application install
public struct KeeperInfo: Equatable {
  /// Keeper contains multiple wallets
  public let wallets: [Wallet]
  
  /// Currently selected wallet
  public let currentWallet: Wallet
  
  /// Currently selected currency
  public let currency: Currency
  
  /// Common pin/faceid settings
  public let securitySettings: SecuritySettings
  
  public let appSettings: AppSettings

  public let country: SelectedCountry
  
  ///
  let assetsPolicy: AssetsPolicy
  let appCollection: AppCollection
}

extension KeeperInfo: Codable {
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.wallets = try container.decode([Wallet].self, forKey: .wallets)
    self.currentWallet = try container.decode(Wallet.self, forKey: .currentWallet)
    self.currency = try container.decode(Currency.self, forKey: .currency)
    self.securitySettings = try container.decode(SecuritySettings.self, forKey: .securitySettings)
    
    if let appSettings = try container.decodeIfPresent(AppSettings.self, forKey: .appSettings) {
      self.appSettings = appSettings
    } else {
      self.appSettings = AppSettings(isSetupFinished: false, isSecureMode: false)
    }
    
    self.assetsPolicy = try container.decode(AssetsPolicy.self, forKey: .assetsPolicy)
    self.appCollection = try container.decode(AppCollection.self, forKey: .appCollection)
    if let selectedCountry = try container.decodeIfPresent(SelectedCountry.self, forKey: .country) {
      self.country = selectedCountry
    } else {
      self.country = .auto
    }
  }
}
