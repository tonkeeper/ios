import Foundation
import CryptoKit

public struct MnemonicsV2Vault {
  
  public enum Error: Swift.Error {
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
      var decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: password)
      decryptedMnemonics[key] = mnemonic
      let encryptedUpdatedMnemonics = try encryptMnemonics(decryptedMnemonics, password: password)
      try keychainVault.saveValue(encryptedUpdatedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    } else {
      let mnemonics = [key: mnemonic]
      let encryptedMnemonics = try encryptMnemonics(mnemonics, password: password)
      try keychainVault.saveValue(encryptedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    }
  }
  
  public func loadMnemonic(key: String, password: String) throws -> Mnemonic {
    do {
      let encryptedMnemonics: Data = try keychainVault.readValue(
        query(
          key: mnemonicsKey,
          accessGroup: accessGroup
        )
      )
      let decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: password)
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
      let encryptedMnemonics: Data = try keychainVault.readValue(
        query(
          key: mnemonicsKey,
          accessGroup: accessGroup
        )
      )
      var decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: password)
      decryptedMnemonics[key] = nil
      let encryptedUpdatedMnemonics = try encryptMnemonics(decryptedMnemonics, password: password)
      try keychainVault.saveValue(encryptedUpdatedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    } catch KeychainVaultError.noItemFound {
      throw Error.noMnemonics
    } catch {
      throw Error.other(error)
    }
  }
  
  public func deleteAll() throws {
    try keychainVault.deleteItem(query(key: mnemonicsKey, accessGroup: accessGroup))
  }
  
  public func changePassword(oldPassword: String, newPassword: String) throws {
    do {
      let encryptedMnemonics: Data = try keychainVault.readValue(
        query(
          key: mnemonicsKey,
          accessGroup: accessGroup
        )
      )
      let decryptedMnemonics = try decryptMnemonics(encryptedMnemonics, password: oldPassword)
      let newPasswordEncryptedMnemonics = try encryptMnemonics(decryptedMnemonics, password: newPassword)
      try keychainVault.saveValue(newPasswordEncryptedMnemonics, to: query(key: mnemonicsKey, accessGroup: accessGroup))
    } catch KeychainVaultError.noItemFound {
      throw Error.noMnemonics
    } catch {
      throw Error.other(error)
    }
  }
  
  public func validatePassword(_ password: String) throws {
    let data: Data = try keychainVault.readValue(
      query(
        key: mnemonicsKey,
        accessGroup: accessGroup
      )
    )
    let _ = try decryptMnemonics(data, password: password)
  }
  
  private func query(key: String,
                     accessGroup: String?) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: "MnemonicsVault",
                                account: key,
                                accessGroup: accessGroup,
                                accessible: .whenUnlockedThisDeviceOnly)
  }
  
  func keyFromPassword(_ password: String) throws -> SymmetricKey {
    let subString = String(password.prefix(32))
    guard let keyData = subString.data(using: .utf8) else {
      throw Error.incorrectPassword(password)
    }
    return SymmetricKey(data: keyData)
  }
  
  private func encryptMnemonics(_ mnemonics: [String: Mnemonic], password: String) throws -> Data {
    do {
      let symmetricKey = try keyFromPassword(password)
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
  
  private func decryptMnemonics(_ encryptedMnemonics: Data, password: String) throws -> [String: Mnemonic] {
    do {
      let symmetricKey = try keyFromPassword(password)
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
