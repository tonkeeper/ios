import Foundation
import CoreComponents
import TonSwift

struct TonConnectAppsVault: KeyValueVault {
  typealias StoreValue = TonConnectApps
  typealias StoreKey = String
  
  private let keychainVault: KeychainVault
  
  public init(keychainVault: KeychainVault) {
    self.keychainVault = keychainVault
  }
  
  func saveValue(_ value: TonConnectApps, for key: String) throws {
    try keychainVault.saveValue(value, to: query(key: key))
  }
  
  func deleteValue(for key: String) throws {
    try keychainVault.deleteItem(query(key: key))
  }
  
  func loadValue(key: String) throws -> TonConnectApps {
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
