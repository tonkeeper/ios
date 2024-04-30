import Foundation

public typealias KeychainQuery = [String: AnyObject]
public typealias KeychainAttributes = [String: AnyObject]

public enum KeychainAccessible {
  case whenUnlocked
  case afterFirstUnlock
  case whenPasscodeSetThisDeviceOnly
  case whenUnlockedThisDeviceOnly
  case afterFirstUnlockThisDeviceOnly
  
  public var keychainKey: CFString {
    switch self {
    case .afterFirstUnlock:
      return kSecAttrAccessibleAfterFirstUnlock
    case .afterFirstUnlockThisDeviceOnly:
      return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    case .whenPasscodeSetThisDeviceOnly:
      return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    case .whenUnlocked:
      return kSecAttrAccessibleWhenUnlocked
    case .whenUnlockedThisDeviceOnly:
      return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }
  }
}

public protocol Keychain {
  func add(_ query: KeychainQuery) -> OSStatus
  func fetch(_ query: KeychainQuery) -> KeychainResult
  func update(_ query: KeychainQuery, with attributes: KeychainAttributes) -> OSStatus
  func delete(_ query: KeychainQuery) -> OSStatus
}

public struct KeychainImplementation: Keychain {
  public init() {}
  
  public func add(_ query: KeychainQuery) -> OSStatus {
    return SecItemAdd(query as CFDictionary, nil)
  }
  
  public func fetch(_ query: KeychainQuery) -> KeychainResult {
    var result: AnyObject?
    let status = withUnsafeMutablePointer(to: &result) {
      SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
    }
    
    return KeychainResult(status: status, result: result)
  }
  
  public func update(_ query: KeychainQuery, with attributes: KeychainAttributes) -> OSStatus {
    return SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
  }
  
  public func delete(_ query: KeychainQuery) -> OSStatus {
    return SecItemDelete(query as CFDictionary)
  }
}
