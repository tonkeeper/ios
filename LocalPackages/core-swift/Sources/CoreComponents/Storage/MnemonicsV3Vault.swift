import Foundation
import TonSwift
import CryptoKit
import CryptoSwift
import TweetNacl

public struct MnemonicsV3Vault {
  public typealias Identifier = String
  public struct EncryptedMnemonics: Codable {
    let N: Int
    let r: Int
    let p: Int
    let salt: String
    let ct: String
  }
  public typealias Mnemonics = [Identifier: Mnemonic]
  
  public enum Error: Swift.Error {
    case mnemonicsCorrupted
    case noMnemonic
    case other(Swift.Error)
  }
  
  private let keychainVault: KeychainVault
  private let seedProvider: () -> String
  
  public init(keychainVault: KeychainVault,
              seedProvider: @escaping () -> String) {
    self.keychainVault = keychainVault
    self.seedProvider = seedProvider
  }

  public func addMnemonic(_ mnemonic: Mnemonic, 
                          identifier: Identifier,
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
  
  public func getMnemonic(identifier: Identifier,
                          password: String) async throws -> Mnemonic {
    let encryptedMnemonics = try loadEncryptedMnemonics()
    let mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
    guard let mnemonic = mnemonics[identifier] else {
      throw Error.noMnemonic
    }
    return mnemonic
  }
  
  public func deleteMnemonic(identifier: Identifier,
                             password: String) async throws {
    let encryptedMnemonics = try loadEncryptedMnemonics()
    var mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
    mnemonics[identifier] = nil
    let encryptedUpdatedMnemonics = try await encryptMnemonics(mnemonics, password: password)
    try saveEncryptedMnemonics(encryptedUpdatedMnemonics)
  }
  
  public func deleteAll() async throws {
    try keychainVault.deleteItem(getMnemonicsVaultQuery())
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
    try keychainVault.saveValue(password, to: query)
  }
  
  public func deletePassword() throws {
    let query = getPasswordQuery()
    try keychainVault.deleteItem(query)
  }
}

private extension MnemonicsV3Vault {
  func getChunksCountQuery() -> KeychainQueryable {
    let key = "\(String.mnemonicsVaultKey)_\(seedProvider())"
    return KeychainGenericPasswordItem(service: .mnemonicsVaultKey,
                                       account: key,
                                       accessGroup: nil,
                                       accessible: .whenUnlockedThisDeviceOnly)
  }
  
  func getChunkQuery(index: Int) -> KeychainQueryable {
    let key = "\(String.encryptedMnemonicsChunkKey)_\(index)_\(seedProvider())"
    return KeychainGenericPasswordItem(service: .mnemonicsVaultKey,
                                       account: key,
                                       accessGroup: nil,
                                       accessible: .whenUnlockedThisDeviceOnly)
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
    let key = "\(String.passwordKey)_\(seedProvider())"
    return KeychainGenericPasswordItem(
      service: .mnemonicsVaultKey,
      account: key,
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

    let mnemonics = try JSONDecoder().decode(Mnemonics.self, from: data)
    return mnemonics
  }
  
  func encryptMnemonics(_ mnemonics: Mnemonics, password: String) async throws -> EncryptedMnemonics {
    let data = try JSONEncoder().encode(mnemonics)
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
        try keychainVault.save(data: Data(chunk), item: query)
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
          let chunk = try keychainVault.read(query)
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

public struct ScryptHashBox {
  private init() {}

  public static func encrypt(data: Data, salt: [UInt8],  N: Int, r: Int, p: Int, password: String) async throws -> String {
    let passwordHash = Data(try Scrypt(
      password: [UInt8](password.utf8),
      salt: salt,
      dkLen: .passwordKeyLength,
      N: .N,
      r: .r,
      p: .p
    ).calculate())
    
    let nonce = Data(salt[0..<24])
    let secretBox = try TweetNacl.NaclSecretBox.secretBox(
      message: data,
      nonce: nonce,
      key: passwordHash
    )
    
    return secretBox.toHexString()
  }
  
  public static func decrypt(string: String, salt: String, N: Int, r: Int, p: Int, password: String) async throws -> Data {
    let passwordHash = Data(try Scrypt(
      password: [UInt8](password.utf8),
      salt: [UInt8](Data(hex: salt)),
      dkLen: .passwordKeyLength,
      N: N,
      r: r,
      p: p
    ).calculate())
    
    let nonce = Data([UInt8](Data(hex: salt))[0..<24])
    
    let data = try TweetNacl.NaclSecretBox.open(box: Data(hex: string),
                                                     nonce: nonce,
                                                     key: Data(passwordHash))
    return data
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
  static let mnemonicsVaultKey = "MnemonicsVault"
  static let encryptedMnemonicsChunksCountKey = "encryptedChunksCount"
  static let encryptedMnemonicsChunkKey = "encryptedChunk"
  static let passwordKey = "password"
}

extension Data {
    var bytes: [UInt8] {
      return [UInt8](self)
    }
}
