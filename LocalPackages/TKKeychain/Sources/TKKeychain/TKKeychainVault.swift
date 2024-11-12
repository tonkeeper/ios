import Foundation

public enum TKKeychainVaultError: Swift.Error {
  case unexpectedData
  case decodingError(DecodingError)
  case encodingError(EncodingError)
}

public protocol TKKeychainVault {
  func get(query: TKKeychainQuery) throws -> Data
  func get(query: TKKeychainQuery) throws -> String
  func get<T: Codable>(query: TKKeychainQuery) throws -> T
  
  func set(_ value: Data, query: TKKeychainQuery) throws
  func set(_ value: String, query: TKKeychainQuery) throws
  func set<T: Codable>(_ value: T, query: TKKeychainQuery) throws
  
  func delete(_ query: TKKeychainQuery) throws
}

public struct TKKeychainVaultImplementation: TKKeychainVault {
  private let keychain: TKKeychain
  
  public init(keychain: TKKeychain) {
    self.keychain = keychain
  }
  
  public func get(query: TKKeychainQuery) throws -> Data {
    guard let data = try keychain.get(query: query) else {
      throw TKKeychainVaultError.unexpectedData
    }
    return data
  }
  
  public func get(query: TKKeychainQuery) throws -> String {
    guard let data = try keychain.get(query: query),
          let string = String(data: data, encoding: .utf8) else {
      throw TKKeychainVaultError.unexpectedData
    }
    return string
  }
  
  public func get<T>(query: TKKeychainQuery) throws -> T where T : Decodable, T : Encodable {
    guard let data = try keychain.get(query: query) else {
      throw TKKeychainVaultError.unexpectedData
    }
    
    let decoder = JSONDecoder()
    do {
      let value = try decoder.decode(T.self, from: data)
      return value
    } catch let decodingError as DecodingError {
      throw TKKeychainVaultError.decodingError(decodingError)
    } catch {
      throw error
    }
  }
  
  public func set(_ value: Data, query: TKKeychainQuery) throws {
    do {
      _ = try keychain.get(query: query)
      try keychain.update(
        query: query,
        attributes: TKKeychainAttributes(data: value)
      )
    } catch TKKeychainError.noItem {
      try keychain.add(data: value, query: query)
    } catch {
      throw error
    }
  }
  
  public func set(_ value: String, query: TKKeychainQuery) throws {
    guard let data = value.data(using: .utf8) else {
      throw TKKeychainVaultError.unexpectedData
    }
    try set(data, query: query)
  }
  
  public func set<T>(_ value: T, query: TKKeychainQuery) throws where T : Decodable, T : Encodable {
    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(value)
      try set(data, query: query)
    } catch let encodingError as EncodingError {
      throw TKKeychainVaultError.encodingError(encodingError)
    } catch {
      throw error
    }
  }
  
  public func delete(_ query: TKKeychainQuery) throws {
    try keychain.delete(query: query)
  }
}
