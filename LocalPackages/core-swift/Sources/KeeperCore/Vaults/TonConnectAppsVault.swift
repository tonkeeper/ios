import Foundation
import CoreComponents
import TKKeychain
import TonSwift

struct TonConnectAppsVault: KeyValueVault {
  typealias StoreValue = TonConnectApps
  typealias StoreKey = Wallet
  
  private let keychainVault: TKKeychainVault
  
  public init(keychainVault: TKKeychainVault) {
    self.keychainVault = keychainVault
  }
  
  func saveValue(_ value: TonConnectApps, for key: StoreKey) throws {
    try keychainVault.set(value, query: query(key: key))
  }
  
  func deleteValue(for key: StoreKey) throws {
    try keychainVault.delete(query(key: key))
  }
  
  func loadValue(key: StoreKey) throws -> TonConnectApps {
    try keychainVault.get(query: query(key: key))
  }
  
  private func query(key: StoreKey) -> TKKeychainQuery {
    TKKeychainQuery(
      item: .genericPassword(service: .key, account: key.id),
      accessGroup: nil,
      biometry: .none,
      accessible: .whenUnlockedThisDeviceOnly
    )
  }
}

// TODO: Delete after open beta

struct TonConnectAppsVaultLegacy: KeyValueVault {
  typealias StoreValue = TonConnectApps
  typealias StoreKey = String
  
  private let keychainVault: TKKeychainVault
  
  public init(keychainVault: TKKeychainVault) {
    self.keychainVault = keychainVault
  }
  
  func saveValue(_ value: TonConnectApps, for key: StoreKey) throws {
    try keychainVault.set(value, query: query(key: key))
  }
  
  func deleteValue(for key: StoreKey) throws {
    try keychainVault.delete(query(key: key))
  }
  
  func loadValue(key: StoreKey) throws -> TonConnectApps {
    try keychainVault.get(query: query(key: key))
  }
  
  private func query(key: StoreKey) -> TKKeychainQuery {
    return TKKeychainQuery(
      item: .genericPassword(service: .key,
                             account: key),
      accessGroup: nil,
      biometry: .none,
      accessible: .whenUnlockedThisDeviceOnly
    )
  }
}

private extension String {
    static let key: String = "TonConnectApps"
}
