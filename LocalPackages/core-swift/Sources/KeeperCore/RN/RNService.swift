import Foundation
import CoreComponents

public protocol RNService {
  func needToMigrate() async -> Bool
  func setMigrationFinished() async throws
  func getWallets() async throws -> [RNWallet]
  func setWallets(_ wallets: [RNWallet]) async throws
  func getActiveWalletId() async throws -> String?
  func setActiveWalletId(_ activeWalletId: String) async throws
  func getWalletBackupDate(walletId: String) async throws -> Date?
  func setWalletBackupDate(date: Date?, walletId: String) async throws
  func getIsBiometryEnable() async throws -> Bool
  func setIsBiometryEnable(_ isBiometryEnable: Bool) async throws
  func getIsLockscreenEnable() async throws -> Bool
  func setIsLockscreenEnable(_ isLockscreenEnable: Bool) async throws
  func getAppTheme() async throws -> RNAppTheme?
  func setAppTheme(_ appTheme: RNAppTheme?) async throws
  func getCurrency() async throws -> Currency
  func getWalletNotificationsSettings(walletId: String) async throws -> Bool
  func setWalletNotificationsSettings(isOn: Bool, walletId: String) async throws
}

final class RNServiceImplementation: RNService {
  private let asyncStorage: RNAsyncStorage
  
  init(asyncStorage: RNAsyncStorage) {
    self.asyncStorage = asyncStorage
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
  
  func getWallets() async throws -> [RNWallet] {
    let walletsStore: RNWalletsStore? = try await asyncStorage.getValue(key: .walletsStore)
    return walletsStore?.wallets ?? []
  }
  
  func setWallets(_ wallets: [RNWallet]) async throws {
    guard !wallets.isEmpty else {
      await asyncStorage.setValue(value: nil, key: .walletsStore)
      return
    }
    let updatedStore: RNWalletsStore
    if let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) {
      updatedStore = RNWalletsStore(
        wallets: wallets,
        selectedIdentifier: walletsStore.selectedIdentifier,
        biometryEnabled: walletsStore.biometryEnabled,
        lockScreenEnabled: walletsStore.lockScreenEnabled
      )
    } else {
      updatedStore = RNWalletsStore(
        wallets: wallets,
        selectedIdentifier: wallets[0].identifier,
        biometryEnabled: false,
        lockScreenEnabled: false
      )
    }
    
    try await asyncStorage.setValue(value: updatedStore, key: .walletsStore)
  }
  
  func getActiveWalletId() async throws -> String? {
    let walletsStore: RNWalletsStore? = try await asyncStorage.getValue(key: .walletsStore)
    return walletsStore?.selectedIdentifier
  }
  
  func setActiveWalletId(_ activeWalletId: String) async throws {
    guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) else {
      return
    }
    let updatedStore = RNWalletsStore(
      wallets: walletsStore.wallets,
      selectedIdentifier: activeWalletId,
      biometryEnabled: walletsStore.biometryEnabled,
      lockScreenEnabled: walletsStore.lockScreenEnabled
    )
    try await asyncStorage.setValue(value: updatedStore, key: .walletsStore)
  }
  
  func getWalletBackupDate(walletId: String) async throws -> Date? {
    let key = "\(walletId)/setup"
    guard let setupState: RNWalletSetupState? = try await asyncStorage.getValue(key: key),
          let lastBackupAt = setupState?.lastBackupAt else {
      return nil
    }
    return Date(timeIntervalSince1970: lastBackupAt / 1000)
  }
  
  func setWalletBackupDate(date: Date?, walletId: String) async throws {
    let key = "\(walletId)/setup"
    let lastBackupAt: Double? = {
      if let date {
        return date.timeIntervalSince1970 * 1000
      } else {
        return nil
      }
    }()
    
    let updatedSetupState: RNWalletSetupState
    if let setupState: RNWalletSetupState = try await asyncStorage.getValue(key: key) {
      updatedSetupState = RNWalletSetupState(
        lastBackupAt: lastBackupAt,
        setupDismissed: setupState.setupDismissed,
        hasOpenedTelegramChannel: setupState.hasOpenedTelegramChannel
      )
    } else {
      updatedSetupState = RNWalletSetupState(
        lastBackupAt: lastBackupAt,
        setupDismissed: false,
        hasOpenedTelegramChannel: false
      )
    }
    try await asyncStorage.setValue(value: updatedSetupState, key: key)
  }
  
  func getIsBiometryEnable() async throws -> Bool {
    let walletsStore: RNWalletsStore? = try await asyncStorage.getValue(key: .walletsStore)
    return walletsStore?.biometryEnabled ?? false
  }
  
  func setIsBiometryEnable(_ isBiometryEnable: Bool) async throws {
    guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) else {
      return
    }
    let updatedStore = RNWalletsStore(
      wallets: walletsStore.wallets,
      selectedIdentifier: walletsStore.selectedIdentifier,
      biometryEnabled: isBiometryEnable,
      lockScreenEnabled: walletsStore.lockScreenEnabled
    )
    try await asyncStorage.setValue(value: updatedStore, key: .walletsStore)
  }
  
  func getIsLockscreenEnable() async throws -> Bool {
    let walletsStore: RNWalletsStore? = try await asyncStorage.getValue(key: .walletsStore)
    return walletsStore?.lockScreenEnabled ?? false
  }
  
  func setIsLockscreenEnable(_ isLockscreenEnable: Bool) async throws {
    guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .walletsStore) else {
      return
    }
    let updatedStore = RNWalletsStore(
      wallets: walletsStore.wallets,
      selectedIdentifier: walletsStore.selectedIdentifier,
      biometryEnabled: walletsStore.biometryEnabled,
      lockScreenEnabled: isLockscreenEnable
    )
    try await asyncStorage.setValue(value: updatedStore, key: .walletsStore)
  }
  
  func getAppTheme() async throws -> RNAppTheme? {
    try await asyncStorage.getValue(key: .appTheme)
  }
  
  func setAppTheme(_ appTheme: RNAppTheme?) async throws {
    try await asyncStorage.setValue(value: appTheme, key: .appTheme)
  }
  
  func getWalletNotificationsSettings(walletId: String) async throws -> Bool {
    let key = "\(walletId)/notifications"
    let walletNotifications: RNWalletNotifications? = try await asyncStorage.getValue(key: key)
    return walletNotifications?.isSubscribed ?? false
  }
  
  func setWalletNotificationsSettings(isOn: Bool, walletId: String) async throws {
    let key = "\(walletId)/notifications"
    let walletNotifications = RNWalletNotifications(isSubscribed: isOn)
    try await asyncStorage.setValue(value: walletNotifications, key: key)
  }
  
  func getCurrency() async throws -> Currency {
    guard let tonPrice: RNTonPrice = try await asyncStorage.getValue(key: "ton_price") else {
      return .USD
    }
    let currencyRaw = tonPrice.currency
    return Currency(rawValue: currencyRaw.uppercased()) ?? .USD
  }
}

private extension String {
  static let walletsStore = "walletsStore"
  static let appTheme = "app-theme"
  static let setup = "setup"
}
