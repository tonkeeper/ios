import Foundation
import CoreComponents
import TonSwift

struct TonConnectAppsVault: KeyValueVault {
  typealias StoreValue = TonConnectApps
  typealias StoreKey = Wallet
  
  private let keychainVault: KeychainVault
  
  public init(keychainVault: KeychainVault) {
    self.keychainVault = keychainVault
  }
  
  func saveValue(_ value: TonConnectApps, for key: StoreKey) throws {
    try keychainVault.saveValue(value, to: query(key: key))
  }
  
  func deleteValue(for key: StoreKey) throws {
    try keychainVault.deleteItem(query(key: key))
  }
  
  func loadValue(key: StoreKey) throws -> TonConnectApps {
    try keychainVault.readValue(query(key: key))
  }
  
  private func query(key: StoreKey) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: .key,
                                account: key.id,
                                accessGroup: nil,
                                accessible: .whenUnlockedThisDeviceOnly)
  }
}

// TODO: Delete after open beta

struct TonConnectAppsVaultLegacy: KeyValueVault {
  typealias StoreValue = TonConnectApps
  typealias StoreKey = String
  
  private let keychainVault: KeychainVault
  
  public init(keychainVault: KeychainVault) {
    self.keychainVault = keychainVault
  }
  
  func saveValue(_ value: TonConnectApps, for key: StoreKey) throws {
    try keychainVault.saveValue(value, to: query(key: key))
  }
  
  func deleteValue(for key: StoreKey) throws {
    try keychainVault.deleteItem(query(key: key))
  }
  
  func loadValue(key: StoreKey) throws -> TonConnectApps {
    try keychainVault.readValue(query(key: key))
  }
  
  private func query(key: StoreKey) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: .key,
                                account: key,
                                accessGroup: nil,
                                accessible: .whenUnlockedThisDeviceOnly)
  }
}

private extension String {
    static let key: String = "TonConnectApps"
}
