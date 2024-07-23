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
    try await migrateMnemonics(isBiometryEnable: walletsStore.biometryEnabled, passcodeProvider: passcodeProvider)
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
  
  private func migrateMnemonics(isBiometryEnable: Bool,
                                passcodeProvider: (_ passcodeValidation: @escaping (String) async -> Bool) async -> String) async throws {
    let chunksCount: Int
    do {
      let chunksCountQuery = keychainQuery(key: "wallets_chunks")
      chunksCount = try keychainVault.readValue(chunksCountQuery)
    } catch {
      throw MnemonicsMigrateError.noWalletsChunksCount
    }
    
    let encryptedMnemonicsString: String
    do {
      encryptedMnemonicsString = try (0..<chunksCount)
        .map {
          let key = "wallets_chunk_\($0)"
          let query = keychainQuery(key: key)
          let chunkData: Data = try keychainVault.read(query)
          guard let chunk = String(data: chunkData, encoding: .utf8) else {
            throw MnemonicsMigrateError.mnemonicsCorrupted
          }
          return chunk
        }
        .reduce(into: "") { $0 = $0 + $1 }
    } catch {
      throw MnemonicsMigrateError.mnemonicsCorrupted
    }
    
    let encryptedMnemonics = try JSONDecoder().decode(
      MnemonicsV3Vault.EncryptedMnemonics.self,
      from: encryptedMnemonicsString.data(
        using: .utf8
      )!
    )
    
    let passcodeValidation: (String) async -> Bool = { passcode in
      do {
        _ = try await ScryptHashBox.decrypt(
          string: encryptedMnemonics.ct,
          salt: encryptedMnemonics.salt,
          N: encryptedMnemonics.N,
          r: encryptedMnemonics.r,
          p: encryptedMnemonics.p,
          password: passcode
        )
        return true
      } catch {
        return false
      }
    }
    
    let passcode = await passcodeProvider(passcodeValidation)
    let decryptedData = try await ScryptHashBox.decrypt(
      string: encryptedMnemonics.ct,
      salt: encryptedMnemonics.salt,
      N: encryptedMnemonics.N,
      r: encryptedMnemonics.r,
      p: encryptedMnemonics.p,
      password: passcode
    )
    let rnMnemonics = try JSONDecoder().decode([String: RNMnemonic].self, from: decryptedData)
    let mnemonics = rnMnemonics.compactMapValues { try? Mnemonic(mnemonicWords: $0.mnemonic.components(separatedBy: " ")) }
    try await mnemonicsRepository.importMnemonics(mnemonics, password: passcode)
    try mnemonicsRepository.savePassword(passcode)
  }
  
  private func keychainQuery(key: String) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: "app",
                                account: key,
                                accessGroup: nil,
                                accessible: .whenUnlocked)
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

private struct RNMnemonic: Decodable {
  let identifier: String
  let mnemonic: String
}
