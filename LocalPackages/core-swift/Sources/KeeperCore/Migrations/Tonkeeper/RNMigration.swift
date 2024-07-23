import Foundation
import TonSwift
import CoreComponents
import CryptoKit

public struct RNMigration {
  
  private let rnService: RNService
  private let walletsStoreUpdater: WalletsStoreUpdater
  private var settingsRepository: SettingsRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let keychainVault: KeychainVault
  private let securityStore: SecurityStoreV2
  
  init(rnService: RNService,
       walletsStoreUpdater: WalletsStoreUpdater,
       settingsRepository: SettingsRepository,
       mnemonicsRepository: MnemonicsRepository,
       keychainVault: KeychainVault,
       securityStore: SecurityStoreV2) {
    self.rnService = rnService
    self.walletsStoreUpdater = walletsStoreUpdater
    self.settingsRepository = settingsRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.keychainVault = keychainVault
    self.securityStore = securityStore
  }
  
  public func checkIfNeedToMigrate() async -> Bool {
    return await rnService.needToMigrate()
  }
  
  public mutating func migrate(passcodeProvider: (_ passcodeValidation: @escaping (String) async -> Bool) async -> String) async throws {
    guard let walletsStore = try? await rnService.getWalletsStore() else {
      return
    }
    await migrateWallets(walletsStore)
    try? await rnService.setMigrationFinished()
  }
  
  enum MigrateError: Swift.Error {
    case failedMigrateWallet
  }
  
  enum MnemonicsMigrateError: Swift.Error {
    case noWalletsChunksCount
    case mnemonicsCorrupted
  }
  
  private mutating func migrateWallets(_ walletsStore: RNWalletsStore) async {
    let rnWallets = walletsStore.wallets
    var wallets = [Wallet]()
    var activeWallet: Wallet?
    for rnWallet in rnWallets {
      let backupDate = try? await rnService.getWalletBackupDate(walletId: rnWallet.identifier)
      guard let wallet = try? rnWallet.getWallet(backupDate: backupDate) else {
        continue
      }
      if rnWallet.identifier == walletsStore.selectedIdentifier {
        activeWallet = wallet
      }
      wallets.append(wallet)
    }
    await walletsStoreUpdater.addWallets(wallets)
    if let activeWallet {
      await walletsStoreUpdater.setWalletActive(activeWallet)
    }
    await securityStore.setIsBiometryEnable(walletsStore.biometryEnabled)
  }
}
