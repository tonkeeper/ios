import Foundation
import TKKeychain
import TonSwift
import CryptoKit
import CryptoSwift
import TweetNacl

public struct MnemonicsVault {
  
  private struct MnemonicItem: Codable {
    let identifier: String
    let mnemonic: String
  }
  
  public enum Error: Swift.Error {
    case mnemonicsCorrupted
    case noMnemonic
    case other(Swift.Error)
  }
  
  private let keychainVault: TKKeychainVault
  private let seedProvider: () -> String
  
  public init(keychainVault: TKKeychainVault,
              seedProvider: @escaping () -> String) {
    self.keychainVault = keychainVault
    self.seedProvider = seedProvider
  }
  
  public func hasMnemonics() -> Bool {
    do {
      _ = try loadEncryptedMnemonics()
      return true
    } catch {
      return false
    }
  }

  public func addMnemonic(_ mnemonic: Mnemonic,
                          identifier: MnemonicIdentifier,
                          password: String) async throws {
    do {
      let encryptedMnemonics = try loadEncryptedMnemonics()
      var mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
      mnemonics[identifier] = mnemonic
      let encryptedUpdatedMnemonics = try await encryptMnemonics(mnemonics, password: password)
      try saveEncryptedMnemonics(encryptedUpdatedMnemonics)
    } catch {
      let mnemonics = [identifier: mnemonic]
      let encryptedMnemonics = try await encryptMnemonics(mnemonics, password: password)
      try saveEncryptedMnemonics(encryptedMnemonics)
    }
  }
  
  public func addMnemoncs(_ mnemonics: Mnemonics, password: String) async throws {
    do {
      let encryptedMnemonics = try loadEncryptedMnemonics()
      var decryptedMnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
      decryptedMnemonics.merge(mnemonics, uniquingKeysWith: { $1 })
      let encryptedUpdatedMnemonics = try await encryptMnemonics(decryptedMnemonics, password: password)
      try saveEncryptedMnemonics(encryptedUpdatedMnemonics)
    } catch {
      let encryptedMnemonics = try await encryptMnemonics(mnemonics, password: password)
      try saveEncryptedMnemonics(encryptedMnemonics)
    }
  }
  
  public func getMnemonic(identifier: MnemonicIdentifier,
                          password: String) async throws -> Mnemonic {
    let encryptedMnemonics = try loadEncryptedMnemonics()
    let mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
    guard let mnemonic = mnemonics[identifier] else {
      throw Error.noMnemonic
    }
    return mnemonic
  }
  
  public func deleteMnemonic(identifier: MnemonicIdentifier,
                             password: String) async throws {
    let encryptedMnemonics = try loadEncryptedMnemonics()
    var mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
    mnemonics[identifier] = nil
    let encryptedUpdatedMnemonics = try await encryptMnemonics(mnemonics, password: password)
    try saveEncryptedMnemonics(encryptedUpdatedMnemonics)
  }
  
  public func deleteAll() async throws {
    try keychainVault.delete(getMnemonicsVaultQuery())
    try deletePassword()
  }
  
  public func changePassword(oldPassword: String,
                             newPassword: String) async throws {
    let encryptedMnemonics = try loadEncryptedMnemonics()
    let decryptedMnemonics = try await decryptMnemonics(encryptedMnemonics, password: oldPassword)
    let reencryptedMnemonics = try await encryptMnemonics(decryptedMnemonics, password: newPassword)
    try saveEncryptedMnemonics(reencryptedMnemonics)
  }
  
  public func validatePassword(_ password: String) async throws {
    let encryptedMnemonics = try loadEncryptedMnemonics()
    _ = try await decryptMnemonics(encryptedMnemonics, password: password)
  }
  
  public func importMnemonics(_ mnemonics: Mnemonics, password: String) async throws {
    let encryptedMnemonics = try await encryptMnemonics(mnemonics, password: password)
    try saveEncryptedMnemonics(encryptedMnemonics)
  }
  
  public func importEncryptedMnemonics(_ encryptedMnemonics: EncryptedMnemonics) throws {
    try saveEncryptedMnemonics(encryptedMnemonics)
  }
  
  public func savePassword(_ password: String) throws {
    let query = getPasswordQuery()
    try keychainVault.set(password, query: query)
  }
  
  public func getPassword() throws -> String {
    let query = getPasswordQuery()
    return try keychainVault.get(query: query)
  }
  
  public func deletePassword() throws {
    let query = getPasswordQuery()
    try keychainVault.delete(query)
  }
}

private extension MnemonicsVault {
  func getChunksCountQuery() -> TKKeychainQuery {
    let service = "\(String.mnemonicsVaultKey)_\(seedProvider())"
    return TKKeychainQuery(
      item: .genericPassword(service: service, account: .encryptedMnemonicsChunksCountKey),
      accessGroup: nil,
      biometry: .none,
      accessible: .whenUnlocked
    )
  }
  
  func getChunkQuery(index: Int) -> TKKeychainQuery {
    let service = "\(String.mnemonicsVaultKey)_\(seedProvider())"
    let key = "\(String.encryptedMnemonicsChunkKey)\(index)"
    return TKKeychainQuery(
      item: .genericPassword(service: service, account: key),
      accessGroup: nil,
      biometry: .none,
      accessible: .whenUnlocked
    )
  }
  
  func getMnemonicsVaultQuery() -> TKKeychainQuery {
    let service = "\(String.mnemonicsVaultKey)_\(seedProvider())"
    return TKKeychainQuery(
      item: .genericPassword(service: service, account: nil),
      accessGroup: nil,
      biometry: .none,
      accessible: .whenUnlockedThisDeviceOnly
    )
  }
  
  func getPasswordQuery() -> TKKeychainQuery {
    let service = "\(String.passwordVaultKey)_\(seedProvider())"
    return TKKeychainQuery(
      item: .genericPassword(service: service, account: .passwordKey),
      accessGroup: nil,
      biometry: .any,
      accessible: .whenUnlockedThisDeviceOnly
    )
  }
  
  func decryptMnemonics(_ encryptedMnemonics: EncryptedMnemonics, password: String) async throws -> Mnemonics {
    let data = try await ScryptHashBox.decrypt(
      string: encryptedMnemonics.ct,
      salt: encryptedMnemonics.salt,
      N: encryptedMnemonics.N,
      r: encryptedMnemonics.r,
      p: encryptedMnemonics.p,
      password: password,
      dkLen: MnemonicsEncryptionParams.passwordKeyLength
    )

    let decrypted = try JSONDecoder().decode([String: MnemonicItem].self, from: data)
    let mnemonics = decrypted.compactMapValues {
      try? Mnemonic(mnemonicWords: $0.mnemonic.components(separatedBy: " "))
    }
    return mnemonics
  }
  
  func encryptMnemonics(_ mnemonics: Mnemonics, password: String) async throws -> EncryptedMnemonics {
    var toEncrypt = [String: MnemonicItem]()
    mnemonics.forEach {
      toEncrypt[$0.key] = MnemonicItem(
        identifier: $0.key,
        mnemonic: $0.value.mnemonicWords.joined(separator: " ")
      )
    }
    let data = try JSONEncoder().encode(toEncrypt)
    
    let salt = try SecureRandom.getRandomBytes(length: 32)
    let ct = try await ScryptHashBox.encrypt(
      data: data,
      salt: salt,
      N: MnemonicsEncryptionParams.N,
      r: MnemonicsEncryptionParams.r,
      p: MnemonicsEncryptionParams.p,
      password: password,
      dkLen: MnemonicsEncryptionParams.passwordKeyLength
    )
    
    let encryptedMnemonics = EncryptedMnemonics(
      kind: "encrypted-scrypt-tweetnacl",
      N: MnemonicsEncryptionParams.N,
      r: MnemonicsEncryptionParams.r,
      p: MnemonicsEncryptionParams.p,
      salt: salt.toHexString(),
      ct: ct
    )
    
    return encryptedMnemonics
  }
  
  func saveEncryptedMnemonics(_ encryptedMnemonics: EncryptedMnemonics) throws {
    let jsonEncoder = JSONEncoder()
    let data = try jsonEncoder.encode(encryptedMnemonics)
    let bytes = [UInt8](data)
    let chunks = stride(from: 0, to: bytes.count, by: .chunksSize).map {
      Array(bytes[$0..<Swift.min($0 + .chunksSize, bytes.count)])
    }
    do {
      try chunks.enumerated().forEach { index, chunk in
        let query = getChunkQuery(index: index)
        try keychainVault.set(Data(chunk), query: query)
      }
      let countQuery = getChunksCountQuery()
      try keychainVault.set(chunks.count, query: countQuery)
    } catch {
      throw Error.other(error)
    }
  }
  
  func loadEncryptedMnemonics() throws -> EncryptedMnemonics {
    let count: Int
    do {
      let countQuery = getChunksCountQuery()
      count = try keychainVault.get(query: countQuery)
    } catch TKKeychainError.noItem {
      throw Error.noMnemonic
    }

    do {
      let encryptedMnemonicsData = try (0..<count)
        .map {
          let query = getChunkQuery(index: $0)
          let chunk: Data = try keychainVault.get(query: query)
          return chunk
        }
        .reduce(into: Data()) { $0 = $0 + $1 }
      let encryptedMnemonics = try JSONDecoder().decode(EncryptedMnemonics.self, from: encryptedMnemonicsData)
      return encryptedMnemonics
    } catch {
      throw Error.mnemonicsCorrupted
    }
  }
}

private extension String {
  static let mnemonicsVaultKey = "mnemonics_vault"
  static let passwordVaultKey = "password_vault"
  static let encryptedMnemonicsChunksCountKey = "encrypted_chunks_count"
  static let encryptedMnemonicsChunkKey = "encrypted_chunk"
  static let passwordKey = "biometry_passcode"
}

private extension Int {
  static let chunksSize = 2048
}
