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
  
  public let batterySettings: BatterySettings
  
  ///
  let assetsPolicy: AssetsPolicy
  let appCollection: AppCollection
  
  public init(wallets: [Wallet],
              currentWallet: Wallet,
              currency: Currency,
              securitySettings: SecuritySettings,
              appSettings: AppSettings,
              country: SelectedCountry,
              batterySettings: BatterySettings = BatterySettings()) {
    self.init(
      wallets: wallets,
      currentWallet: currentWallet,
      currency: currency,
      securitySettings: securitySettings,
      appSettings: appSettings,
      country: country,
      batterySettings: batterySettings,
      assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
      appCollection: AppCollection(connected: [:], recent: [], pinned: [])
    )
  }
  
  init(wallets: [Wallet],
       currentWallet: Wallet,
       currency: Currency,
       securitySettings: SecuritySettings,
       appSettings: AppSettings,
       country: SelectedCountry,
       batterySettings: BatterySettings,
       assetsPolicy: AssetsPolicy,
       appCollection: AppCollection) {
    self.wallets = wallets
    self.currentWallet = currentWallet
    self.currency = currency
    self.securitySettings = securitySettings
    self.appSettings = appSettings
    self.country = country
    self.batterySettings = batterySettings
    self.assetsPolicy = assetsPolicy
    self.appCollection = appCollection
  }
  
}

extension KeeperInfo: Codable {
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    // TODO: Delete after open beta
    let wallets = try container.decode([Wallet].self, forKey: .wallets)
    var filteredWallets = [Wallet]()
    wallets.forEach { wallet in
      guard !filteredWallets.contains(where: { $0.identity == wallet.identity || $0.id == wallet.id }) else { return }
      filteredWallets.append(wallet)
    }

    self.wallets = filteredWallets
    
    self.currentWallet = try container.decode(Wallet.self, forKey: .currentWallet)
    self.currency = try container.decode(Currency.self, forKey: .currency)
    self.securitySettings = try container.decode(SecuritySettings.self, forKey: .securitySettings)
    
    if let appSettings = try container.decodeIfPresent(AppSettings.self, forKey: .appSettings) {
      self.appSettings = appSettings
    } else {
      self.appSettings = AppSettings(isSecureMode: false, searchEngine: .duckduckgo)
    }
    
    self.assetsPolicy = try container.decode(AssetsPolicy.self, forKey: .assetsPolicy)
    self.appCollection = try container.decode(AppCollection.self, forKey: .appCollection)
    if let selectedCountry = try container.decodeIfPresent(SelectedCountry.self, forKey: .country) {
      self.country = selectedCountry
    } else {
      self.country = .auto
    }
    
    if let batterySettings = try container.decodeIfPresent(BatterySettings.self, forKey: .batterySettings) {
      self.batterySettings = batterySettings
    } else {
      self.batterySettings = BatterySettings()
    }
  }
}
