import Foundation
import TKUIKit
import KeeperCore

struct RNMigration {
  
  enum MigrateError: Swift.Error {
    case noWallets
    case failedMigrateWallet(identifier: String, publicKey: String)
  }
  
  private let rnService: RNService
  private let walletsStore: WalletsStore
  private let securityStore: SecurityStore
  private let currencyStore: CurrencyStore
  private let walletNotificationStore: WalletNotificationStore
  
  init(rnService: RNService, 
       walletsStore: WalletsStore,
       securityStore: SecurityStore,
       currencyStore: CurrencyStore,
       walletNotificationStore: WalletNotificationStore) {
    self.rnService = rnService
    self.walletsStore = walletsStore
    self.securityStore = securityStore
    self.currencyStore = currencyStore
    self.walletNotificationStore = walletNotificationStore
  }
  
  func checkIfNeedToMigrate() async -> Bool {
    return await rnService.needToMigrate()
  }
  
  func performMigration() async -> [MigrateError] {
    guard let rnWallets = try? await rnService.getWallets() else {
      return [.noWallets]
    }
    let activeWalletId = try? await rnService.getActiveWalletId()
    
    var errors = [MigrateError]()
    
    var wallets = [Wallet]()
    for rnWallet in rnWallets {
      let backupDate = try? await rnService.getWalletBackupDate(walletId: rnWallet.identifier)
      guard let wallet = try? rnWallet.getWallet(backupDate: backupDate) else {
        errors.append(.failedMigrateWallet(identifier: rnWallet.identifier, publicKey: rnWallet.pubkey))
        continue
      }
      guard !wallets.contains(where: { $0.identity == wallet.identity }) else { continue }
      wallets.append(wallet)
    }

    guard !wallets.isEmpty else { return errors }

    let activeWallet = wallets.first(where: {
      $0.id == activeWalletId
    }) ?? wallets[0]
    
    await walletsStore.addWallets(wallets)
    await walletsStore.makeWalletActive(activeWallet)
    try? _ = await securityStore.setIsBiometryEnable(rnService.getIsBiometryEnable())
    await migrateCurrency()
    await migrateNotificationsSettings(wallets: wallets)
    await migrateTheme()
    return errors
  }
  
  private func migrateCurrency() async {
    let currency: Currency = await {
      do {
        return try await rnService.getCurrency()
      } catch {
        return .USD
      }
    }()
    await currencyStore.setCurrency(currency)
  }
  
  private func migrateTheme() async {
    let theme: TKTheme = await {
      guard let selectedTheme = try? await rnService.getAppTheme()?.state.selectedTheme else {
        return .deepBlue
      }
      return TKTheme(rawValue: selectedTheme) ?? .deepBlue
    }()
    await MainActor.run {
      TKThemeManager.shared.theme = theme
    }
  }

  private func migrateNotificationsSettings(wallets: [Wallet]) async {
    for wallet in wallets {
      let isOn = (try? await rnService.getWalletNotificationsSettings(walletId: wallet.id)) ?? false
      await walletNotificationStore.setNotificationIsOn(isOn, wallet: wallet)
    }
  }
}
