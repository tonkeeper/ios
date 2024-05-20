import Foundation
import TonSwift
import CryptoKit

public struct MnemonicsV2Vault {
  
  public enum Error: Swift.Error {
    case failedGenerateSalt
    case noMnemonics
    case incorrectPassword(_ password: String)
    case failedToEncrypt(Swift.Error?)
    case failedToDecrypt(Swift.Error?)
    case noMnemonic(key: String)
    case other(Swift.Error)
  }
  
  private let seedProvider: () -> String
  private let keychainVault: KeychainVault
  private let accessGroup: String?
  
  public init(seedProvider: @escaping () -> String,
              keychainVault: KeychainVault,
              accessGroup: String?) {
    self.seedProvider = seedProvider
    self.keychainVault = keychainVault
    self.accessGroup = accessGroup
  }
  
  public func saveMnemonic(_ mnemonic: Mnemonic, key: String, password: String) throws {
    if let encryptedMnemonics: Data = try? keychainVault.readValue(
      query(
        key: mnemonicsKey,
        accessGroup: accessGroup
      )
    ) {
      let salt: Data = try keychainVault.readValue(saltQuery())
      var decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: password, salt: salt)
      decryptedMnemonics[key] = mnemonic
      let encryptedUpdatedMnemonics = try encryptMnemonics(decryptedMnemonics, password: password, salt: salt)
      try keychainVault.saveValue(encryptedUpdatedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    } else {
      let salt = Data(try secureRandomBytes(count: 32))
      try keychainVault.saveValue(salt, to: saltQuery())
      let mnemonics = [key: mnemonic]
      let encryptedMnemonics = try encryptMnemonics(mnemonics, password: password, salt: salt)
      try keychainVault.saveValue(encryptedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    }
  }
  
  public func loadMnemonic(key: String, password: String) throws -> Mnemonic {
    do {
      let salt: Data = try keychainVault.readValue(saltQuery())
      let encryptedMnemonics: Data = try keychainVault.readValue(
        query(
          key: mnemonicsKey,
          accessGroup: accessGroup
        )
      )
      let decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: password, salt: salt)
      guard let mnemonic = decryptedMnemonics[key] else {
        throw Error.noMnemonic(key: key)
      }
      return mnemonic
    } catch KeychainVaultError.noItemFound {
      throw Error.noMnemonics
    } catch {
      throw Error.other(error)
    }
  }
  
  public func deleteMnemonic(key: String, password: String) throws {
    do {
      let salt: Data = try keychainVault.readValue(saltQuery())
      let encryptedMnemonics: Data = try keychainVault.readValue(
        query(
          key: mnemonicsKey,
          accessGroup: accessGroup
        )
      )
      var decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: password, salt: salt)
      decryptedMnemonics[key] = nil
      let encryptedUpdatedMnemonics = try encryptMnemonics(decryptedMnemonics, password: password, salt: salt)
      try keychainVault.saveValue(encryptedUpdatedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    } catch KeychainVaultError.noItemFound {
      throw Error.noMnemonics
    } catch {
      throw Error.other(error)
    }
  }
  
  public func deleteAll() throws {
    try keychainVault.deleteItem(query(key: mnemonicsKey, accessGroup: accessGroup))
    try keychainVault.deleteItem(saltQuery())
  }
  
  public func changePassword(oldPassword: String, newPassword: String) throws {
    do {
      let salt: Data = try keychainVault.readValue(saltQuery())
      let encryptedMnemonics: Data = try keychainVault.readValue(
        query(
          key: mnemonicsKey,
          accessGroup: accessGroup
        )
      )
      let decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: oldPassword, salt: salt)
      let newPasswordEncryptedMnemonics = try encryptMnemonics(decryptedMnemonics, password: newPassword, salt: salt)
      try keychainVault.saveValue(newPasswordEncryptedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    } catch KeychainVaultError.noItemFound {
      throw Error.noMnemonics
    } catch {
      throw Error.other(error)
    }
  }
  
  public func validatePassword(_ password: String) throws {
    try? migrateIfNeeded(password: password)
    let salt: Data = try keychainVault.readValue(saltQuery())
    let data: Data = try keychainVault.readValue(
      query(
        key: mnemonicsKey,
        accessGroup: accessGroup
      )
    )
    let _ = try decryptMnemonics(data, password: password, salt: salt)
  }
  
  private func query(key: String,
                     accessGroup: String?) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: "MnemonicsVault",
                                account: key,
                                accessGroup: accessGroup,
                                accessible: .whenUnlockedThisDeviceOnly)
  }
  
  private func saltQuery() -> KeychainQueryable {
    KeychainGenericPasswordItem(service: "MnemonicsVault",
                                account: "salt",
                                accessGroup: accessGroup,
                                accessible: .whenUnlockedThisDeviceOnly)
  }
  
  private func migrateIfNeeded(password: String) throws {
    let data: Data = try keychainVault.readValue(
      query(
        key: mnemonicsKey,
        accessGroup: accessGroup
      )
    )
    let substring = String(password.prefix(32))
    guard let keyData = substring.data(using: .utf8) else {
      throw Error.incorrectPassword(password)
    }
    let key = SymmetricKey(data: keyData)
    do {
      let sealedBox = try AES.GCM.SealedBox(combined: data)
      let decryptedData = try AES.GCM.open(sealedBox, using: key)
      let mnemonics = try JSONDecoder().decode([String: Mnemonic].self, from: decryptedData)
      let salt = Data(try secureRandomBytes(count: 32))
      try keychainVault.saveValue(salt, to: saltQuery())
      let encryptedMnemonics = try encryptMnemonics(
        mnemonics,
        password: password,
        salt: salt
      )
      try keychainVault.saveValue(
        encryptedMnemonics,
        to: query(key: mnemonicsKey, accessGroup: accessGroup)
      )
    } catch { return }
  }
  
  func keyFromPassword(_ password: String, salt: Data) throws -> SymmetricKey {
    guard let passwordData = password.data(using: .utf8) else {
      throw Error.incorrectPassword(password)
    }
    let passwordHash = pbkdf2Sha512(phrase: passwordData, salt: salt)
    guard passwordHash.count >= 32 else {
      throw Error.incorrectPassword(password)
    }
    let keyData = passwordHash[0..<32]
    return SymmetricKey(data: Data(keyData))
  }
  
  private func encryptMnemonics(_ mnemonics: [String: Mnemonic], password: String, salt: Data) throws -> Data {
    do {
      let symmetricKey = try keyFromPassword(password, salt: salt)
      let data = try JSONEncoder().encode(mnemonics)
      let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
      guard let data = sealedBox.combined else {
        throw Error.failedToEncrypt(nil)
      }
      return data
    } catch CryptoKitError.authenticationFailure {
      throw Error.incorrectPassword(password)
    } catch {
      throw Error.failedToEncrypt(error)
    }
  }
  
  private func decryptMnemonics(_ encryptedMnemonics: Data, password: String, salt: Data) throws -> [String: Mnemonic] {
    do {
      let symmetricKey = try keyFromPassword(password, salt: salt)
      let sealedBox = try AES.GCM.SealedBox(combined: encryptedMnemonics)
      let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
      return try JSONDecoder().decode([String: Mnemonic].self, from: decryptedData)
    } catch CryptoKitError.authenticationFailure {
      throw Error.incorrectPassword(password)
    } catch {
      throw Error.failedToDecrypt(error)
    }
  }
  
  private var mnemonicsKey: String {
    "\(String.mnemonicsKey)_\(seedProvider())"
  }
  
  private func secureRandomBytes(count: Int) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: count)
    let status = SecRandomCopyBytes(
      kSecRandomDefault,
      count,
      &bytes
    )
    if status == errSecSuccess {
      return bytes
    }
    else {
      throw Error.failedGenerateSalt
    }
  }
}

private extension String {
  static let mnemonicsKey = "mnemonics"
}

public extension String {
  var hashed: String {
    guard let data = data(using: .utf8) else { return "" }
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02hhx", $0) }.joined()
  }
}
