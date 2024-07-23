import Foundation
import TonSwift
import CryptoKit
import CryptoSwift
import TweetNacl

public struct MnemonicsV4Vault {
  private struct MnemonicItem: Codable {
    let identifier: String
    let mnemonic: String
  }
  
  public struct EncryptedMnemonics: Codable {
    public let kind: String
    public let N: Int
    public let r: Int
    public let p: Int
    public let salt: String
    public let ct: String
  }
  
  public enum Error: Swift.Error {
    case mnemonicsCorrupted
    case noMnemonic
    case other(Swift.Error)
  }
  
  private let keychainVault: KeychainVault
  
  public init(keychainVault: KeychainVault) {
    self.keychainVault = keychainVault
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
    try keychainVault.deleteItem(getMnemonicsVaultQuery())
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
  
  public func savePassword(_ password: String) throws {
    let query = getPasswordQuery()
    try keychainVault.save(password, item: query)
  }
  
  public func getPassword() throws -> String {
    let query = getPasswordQuery()
    return try keychainVault.read(query)
  }
  
  public func deletePassword() throws {
    let query = getPasswordQuery()
    try keychainVault.deleteItem(query)
  }
}

private extension MnemonicsV4Vault {
  func getChunksCountQuery() -> KeychainQueryable {
    return KeychainGenericPasswordItem(service: .mnemonicsVaultKey,
                                       account: .encryptedMnemonicsChunksCountKey,
                                       accessGroup: nil,
                                       accessible: .whenUnlocked)
  }
  
  func getChunkQuery(index: Int) -> KeychainQueryable {
    let key = "\(String.encryptedMnemonicsChunkKey)\(index)"
    return KeychainGenericPasswordItem(service: .mnemonicsVaultKey,
                                       account: key,
                                       accessGroup: nil,
                                       accessible: .whenUnlocked)
  }
  
  func getMnemonicsVaultQuery() -> KeychainQueryable {
    return KeychainGenericPasswordItem(
      service: .mnemonicsVaultKey,
      account: nil,
      accessGroup: nil,
      accessible: .whenUnlockedThisDeviceOnly
    )
  }
  
  func getPasswordQuery() -> KeychainQueryable {
    return KeychainGenericPasswordItem(
      service: .passwordVaultKey,
      account: .passwordKey,
      accessGroup: nil,
      accessible: .whenUnlockedThisDeviceOnly,
      isBiometry: true
    )
  }
  
  func decryptMnemonics(_ encryptedMnemonics: EncryptedMnemonics, password: String) async throws -> Mnemonics {
    let data = try await ScryptHashBox.decrypt(
      string: encryptedMnemonics.ct,
      salt: encryptedMnemonics.salt,
      N: encryptedMnemonics.N,
      r: encryptedMnemonics.r,
      p: encryptedMnemonics.p,
      password: password
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
      N: .N,
      r: .r,
      p: .p,
      password: password
    )
    
    let encryptedMnemonics = EncryptedMnemonics(
      kind: "encrypted-scrypt-tweetnacl",
      N: .N,
      r: .r,
      p: .p,
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
        try keychainVault.save(Data(chunk), item: query)
      }
      let countQuery = getChunksCountQuery()
      try keychainVault.saveValue(chunks.count, to: countQuery)
    } catch {
      throw Error.other(error)
    }
  }
  
  func loadEncryptedMnemonics() throws -> EncryptedMnemonics {
    let count: Int
    do {
      let countQuery = getChunksCountQuery()
      count = try keychainVault.readValue(countQuery)
    } catch KeychainVaultError.noItemFound {
      throw Error.noMnemonic
    }

    do {
      let encryptedMnemonicsData = try (0..<count)
        .map {
          let query = getChunkQuery(index: $0)
          let chunk: Data = try keychainVault.read(query)
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

private struct SecureRandom {
  enum Error: Swift.Error {
    case generationFailed
  }
  
  private init() {}
  
  static func getRandomBytes(length: Int) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(
      kSecRandomDefault,
      length,
      &bytes
    )
    if status == errSecSuccess {
      return bytes
    } else {
      throw Error.generationFailed
    }
  }
}

private extension Int {
  static let N = 16384
  static let r = 8
  static let p = 1
  static let chunksSize = 2048
  static let passwordKeyLength = 32
}

private extension String {
  static let mnemonicsVaultKey = "app"
  static let passwordVaultKey = "TKProtected"
  static let encryptedMnemonicsChunksCountKey = "wallets_chunks"
  static let encryptedMnemonicsChunkKey = "wallets_chunk_"
  static let passwordKey = "biometry_passcode"
}
