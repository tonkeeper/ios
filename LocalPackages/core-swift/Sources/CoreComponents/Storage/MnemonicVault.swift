import Foundation

public struct MnemonicVault: KeyValueVault {
  public typealias StoreValue = Mnemonic
  public typealias StoreKey = String
  
  private let keychainVault: KeychainVault
  private let accessGroup: String?
  
  public init(keychainVault: KeychainVault,
              accessGroup: String?) {
    self.keychainVault = keychainVault
    self.accessGroup = accessGroup
  }
  
  public func saveValue(_ value: Mnemonic, for key: StoreKey) throws {
    try keychainVault.saveValue(value, to: query(key: key, accessGroup: accessGroup))
  }
  
  public func deleteValue(for key: StoreKey) throws {
    try keychainVault.deleteItem(query(key: key, accessGroup: accessGroup))
  }
  
  public func loadValue(key: StoreKey) throws -> Mnemonic {
    try keychainVault.readValue(query(key: key, accessGroup: accessGroup))
  }
  
  public func deleteAllValues() throws {
    try keychainVault.deleteItem(KeychainGenericPasswordItem(service: "MnemonicVault",
                                                             account: nil,
                                                             accessGroup: accessGroup,
                                                             accessible: .whenUnlockedThisDeviceOnly))
  }
  
  private func query(key: StoreKey,
                     accessGroup: String?) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: "MnemonicVault",
                                account: key,
                                accessGroup: accessGroup,
                                accessible: .whenUnlockedThisDeviceOnly)
  }
}
