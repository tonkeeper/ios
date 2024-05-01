import Foundation

public struct PasswordVault {
  public enum Error: Swift.Error {
    case failedToLoadPasscode
    case failedToSavePasscode
  }
  
  private let keychainVault: KeychainVault
  
  public init(keychainVault: KeychainVault) {
    self.keychainVault = keychainVault
  }
  
  public func load() throws -> String {
    try keychainVault.readValue(String.query())
  }
  
  public func save(_ password: String) throws {
    try keychainVault.saveValue(password, to: String.query())
  }
}

private extension String {
    static func query() throws -> KeychainQueryable {
        KeychainGenericPasswordItem(service: "PasswordVault",
                                    account: "Password",
                                    accessGroup: nil,
                                    accessible: .whenUnlockedThisDeviceOnly)
    }
}
