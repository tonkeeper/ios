import Foundation
import TKKeychain

public struct UniqueIdProvider {
  
  public var uniqueDeviceId: UUID {
    getOrCreateUniqueDeviceId()
  }
  public var uniqueInstallId: UUID {
    getOrCreateUniqueInstallId()
  }
  
  private let lock = NSLock()
  
  private let userDefaults: UserDefaults
  private let keychainVault: TKKeychainVault
  
  init(userDefaults: UserDefaults,
       keychainVault: TKKeychainVault) {
    self.userDefaults = userDefaults
    self.keychainVault = keychainVault
  }
  
  private func getOrCreateUniqueDeviceId() -> UUID {
    lock.withLock {
      if let uuid: UUID = try? keychainVault.get(query: createUniqueDeviceIdKeychainQuery()) {
        return uuid
      } else {
        let uuid = UUID()
        try? keychainVault.set(uuid, query: createUniqueDeviceIdKeychainQuery())
        return uuid
      }
    }
  }
  
  private func getOrCreateUniqueInstallId() -> UUID {
    lock.withLock {
      if let uuidString = userDefaults.string(forKey: .user_defaults_unique_install_id_key),
         let uuid = UUID(uuidString: uuidString) {
        return uuid
      } else {
        let uuid = UUID()
        userDefaults.set(uuid.uuidString, forKey: .user_defaults_unique_install_id_key)
        return uuid
      }
    }
  }
  
  private func createUniqueDeviceIdKeychainQuery() -> TKKeychainQuery {
    TKKeychainQuery(
      item: .genericPassword(service: .keychain_unique_device_id_service, account: nil),
      accessGroup: nil,
      biometry: .none,
      accessible: .afterFirstUnlock
    )
  }
}

private extension String {
  static let user_defaults_unique_install_id_key = "tkcore_unique_install_id"
  static let keychain_unique_device_id_service = "unique_device_id_service"
  static let keychain_unique_device_id_account = "unique_device_id"
}
