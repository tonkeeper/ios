import Foundation
import CoreComponents

public protocol RNService {
  func needToMigrate() async -> Bool
  func setMigrationFinished() async throws
  func getWalletsStore() async throws -> RNWalletsStore?
  func getWalletBackupDate(walletId: String) async throws -> Date?
  func addWallets(_ wallets: [RNWallet]) async throws
  func setWalletActive(_ wallet: RNWallet) async throws
  func updateWalletMetaData(_ wallet: RNWallet, metaData: WalletMetaData) async throws
  func updateWallet(_ wallet: RNWallet, lastBackupAt: TimeInterval?) async throws
  func moveWallet(fromIndex: Int, toIndex: Int) async throws
  func deleteWallet(_ wallet: RNWallet) async throws
  func deleteAllWallets() async throws
  func isBiometryEnable() async -> Bool
  func getBiometryPasscode() async throws -> String
}

final class RNServiceImplementation: RNService {
  private let asyncStorage: RNAsyncStorage
  private let keychainVault: KeychainVault
  
  init(asyncStorage: RNAsyncStorage,
       keychainVault: KeychainVault) {
    self.asyncStorage = asyncStorage
    self.keychainVault = keychainVault
  }
  
  func needToMigrate() async -> Bool {
    do {
      let xFlag: Bool? = try await asyncStorage.getValue(key: "x")
      if xFlag != true, let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) {
        return !walletsStore.wallets.isEmpty
      }
      return false
    } catch {
      return false
    }
  }
  
  func setMigrationFinished() async throws {
    try await asyncStorage.setValue(value: true, key: "x")
  }
  
  func getWalletsStore() async throws -> RNWalletsStore? {
    try await asyncStorage.getValue(key: .walletsStore)
  }
  
  func getWalletBackupDate(walletId: String) async throws -> Date? {
    let key = "\(walletId)/setup"
    guard let setupState: RNWalletSetupState? = try await asyncStorage.getValue(key: key),
          let lastBackupAt = setupState?.lastBackupAt else {
      return nil
    }
    return Date(timeIntervalSince1970: lastBackupAt / 1000)
  }
  
  func addWallets(_ wallets: [RNWallet]) async throws {
    guard !wallets.isEmpty else { return }
    if let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) {
      let addWalletsIdentifiers = wallets.map { $0.identifier }
      let currentWallets = walletsStore.wallets
        .filter { wallet in !addWalletsIdentifiers.contains(wallet.identifier) }
      let resultWallets = currentWallets + wallets
      let updatedWalletsStore = RNWalletsStore(
        wallets: resultWallets,
        selectedIdentifier: walletsStore.selectedIdentifier,
        biometryEnabled: walletsStore.biometryEnabled,
        lockScreenEnabled: walletsStore.lockScreenEnabled
      )
      try await asyncStorage.setValue(value: updatedWalletsStore, key: .walletsStore)
    } else {
      let walletsStore = RNWalletsStore(
        wallets: wallets,
        selectedIdentifier: wallets[0].identifier,
        biometryEnabled: false,
        lockScreenEnabled: false
      )
      try await asyncStorage.setValue(value: walletsStore, key: .walletsStore)
    }
  }
  
  func setWalletActive(_ wallet: RNWallet) async throws {
    guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) else {
      return
    }
    
    let updatedWalletsStore = RNWalletsStore(
      wallets: walletsStore.wallets,
      selectedIdentifier: wallet.identifier,
      biometryEnabled: walletsStore.biometryEnabled,
      lockScreenEnabled: walletsStore.lockScreenEnabled
    )
    try await asyncStorage.setValue(value: updatedWalletsStore, key: .walletsStore)
  }
  
  func updateWalletMetaData(_ wallet: RNWallet, metaData: WalletMetaData) async throws {
    guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore),
    let rnWallet = walletsStore.wallets.first(where: { $0.identifier == wallet.identifier })  else {
      return
    }
    
    let updatedRnWallet = RNWallet(
      identifier: rnWallet.identifier,
      name: rnWallet.name,
      emoji: {
        switch metaData.icon {
        case .emoji(let emoji):
          return emoji
        case .icon(let image):
          return image.rawValue
        }
      }(),
      color: metaData.tintColor.rawValue,
      pubkey: rnWallet.pubkey,
      network: rnWallet.network,
      type: rnWallet.type,
      version: rnWallet.version,
      workchain: rnWallet.workchain,
      ledger: rnWallet.ledger
    )
    
    let updatedWallets = walletsStore.wallets.map {
      if $0.identifier == updatedRnWallet.identifier {
        return updatedRnWallet
      }
      return $0
    }
    let updatedWalletsStore = RNWalletsStore(
      wallets: updatedWallets,
      selectedIdentifier: walletsStore.selectedIdentifier,
      biometryEnabled: walletsStore.biometryEnabled,
      lockScreenEnabled: walletsStore.lockScreenEnabled
    )
    try await asyncStorage.setValue(value: updatedWalletsStore, key: .walletsStore)
  }
  
  func updateWallet(_ wallet: RNWallet, lastBackupAt: TimeInterval?) async throws {
    let key = "\(wallet.identifier)/setup"
    if let walletSetupState: RNWalletSetupState = try? await asyncStorage.getValue(key: key) {
      let updatedWalletSetupState = RNWalletSetupState(
        lastBackupAt: lastBackupAt,
        setupDismissed: walletSetupState.setupDismissed,
        hasOpenedTelegramChannel: walletSetupState.hasOpenedTelegramChannel
      )
      try await asyncStorage.setValue(value: updatedWalletSetupState, key: key)
    } else {
      let walletSetupState = RNWalletSetupState(
        lastBackupAt: lastBackupAt,
        setupDismissed: false,
        hasOpenedTelegramChannel: false
      )
      try await asyncStorage.setValue(value: walletSetupState, key: key)
    }
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) async throws {
    guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) else {
      return
    }
    guard fromIndex < walletsStore.wallets.count,
          fromIndex >= 0,
          toIndex < walletsStore.wallets.count,
          toIndex >= 0 else {
      return
    }
    
    var wallets = walletsStore.wallets
    let wallet = wallets.remove(at: fromIndex)
    wallets.insert(wallet, at: toIndex)
    
    let updatedWalletsStore = RNWalletsStore(
      wallets: wallets,
      selectedIdentifier: walletsStore.selectedIdentifier,
      biometryEnabled: walletsStore.biometryEnabled,
      lockScreenEnabled: walletsStore.lockScreenEnabled
    )
    try await asyncStorage.setValue(value: updatedWalletsStore, key: .walletsStore)
  }
  
  func deleteWallet(_ wallet: RNWallet) async throws {
    guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) else {
      return
    }
    let wallets = walletsStore.wallets.filter { $0.identifier != wallet.identifier }
    if wallets.isEmpty {
      await asyncStorage.setValue(value: nil, key: .walletsStore)
    } else {
      var selectedIdentifier = walletsStore.selectedIdentifier
      if walletsStore.selectedIdentifier == wallet.identifier {
        selectedIdentifier = wallets[0].identifier
      }
      let updatedWalletsStore = RNWalletsStore(
        wallets: wallets,
        selectedIdentifier: selectedIdentifier,
        biometryEnabled: walletsStore.biometryEnabled,
        lockScreenEnabled: walletsStore.lockScreenEnabled
      )
      try await asyncStorage.setValue(value: updatedWalletsStore, key: .walletsStore)
    }
  }
  
  func deleteAllWallets() async throws {
    await asyncStorage.setValue(value: nil, key: .walletsStore)
  }
  
  func getBiometryPasscode() async throws -> String {
    let query = biometryPasscodeKeychainQuery()
    do {
      return try keychainVault.read(query)
    } catch {
      throw error
    }
  }
  
  func isBiometryEnable() async -> Bool {
    do {
      let walletsStore: RNWalletsStore? = try await asyncStorage.getValue(key: .walletsStore)
      return walletsStore?.biometryEnabled ?? false
    } catch {
      return false
    }
  }
  
  private func biometryPasscodeKeychainQuery() -> KeychainQueryable {
    KeychainGenericPasswordItem(service: "TKProtected",
                                account: "biometry_passcode",
                                accessGroup: nil,
                                accessible: .whenUnlockedThisDeviceOnly,
                                isBiometry: true)
  }
}

private extension String {
  static let walletsStore = "walletsStore"
  static let setup = "setup"
}
