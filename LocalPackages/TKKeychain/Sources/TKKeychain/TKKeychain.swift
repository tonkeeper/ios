import Foundation

public enum TKKeychainAccessible {
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

public enum TKKeychainAttributeKey: Hashable {
  case valueData
  
  var key: String {
    switch self {
    case .valueData:
      kSecClass as String
    }
  }
}

public enum TKKeychainBiometry {
  case none
  case any
  case current
}

public enum TKKeychainItem {
  case genericPassword(service: String, account: String?)
}

public struct TKKeychainQuery {
  public let item: TKKeychainItem
  public let accessGroup: String?
  public let biometry: TKKeychainBiometry
  public let accessible: TKKeychainAccessible
  
  var query: [CFString: AnyObject] {
    var query = [CFString: AnyObject]()
    switch item {
    case .genericPassword(let service, let account):
      query[kSecClass] = kSecClassGenericPassword
      query[kSecAttrService] = service as AnyObject
      if let account {
        query[kSecAttrAccount] = account as AnyObject
      }
    }

    if let accessGroup {
      query[kSecAttrAccessGroup] = accessGroup as AnyObject
    }
    
    switch biometry {
    case .none:
      query[kSecAttrAccessible] = accessible.keychainKey
    case .any:
      let accessOptions = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        accessible.keychainKey,
        SecAccessControlCreateFlags.biometryAny,
        nil
      )
      query[kSecAttrAccessControl] = accessOptions
    case .current:
      let accessOptions = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        accessible.keychainKey,
        SecAccessControlCreateFlags.biometryCurrentSet,
        nil
      )
      query[kSecAttrAccessControl] = accessOptions
    }
    
    return query
  }
  
  public init(item: TKKeychainItem,
              accessGroup: String?,
              biometry: TKKeychainBiometry,
              accessible: TKKeychainAccessible) {
    self.item = item
    self.accessGroup = accessGroup
    self.biometry = biometry
    self.accessible = accessible
  }
}

public struct TKKeychainAttributes {
  public let data: Data
  
  var attributes: [CFString: AnyObject] {
    var attributes = [CFString: AnyObject]()
    attributes[kSecValueData] = data as AnyObject
    return attributes
  }
}

public enum TKKeychainStatus {
  case success
  case failure(TKKeychainError)
  
  init(status: OSStatus) {
    switch status {
    case noErr:
      self = .success
    default:
      self = .failure(TKKeychainError(status: status))
    }
  }
}

public enum TKKeychainError: Swift.Error {
  case corruptedData
  case noItem
  case other(OSStatus)
  
  init(status: OSStatus) {
    switch status {
    case errSecItemNotFound:
      self = .noItem
    default:
      self = .other(status)
    }
  }
}

public protocol TKKeychain {
  func add(data: Data, query: TKKeychainQuery) throws
  func get(query: TKKeychainQuery) throws -> Data?
  func update(query: TKKeychainQuery, attributes: TKKeychainAttributes) throws
  func delete(query: TKKeychainQuery) throws
}

public final class TKKeychainImplementation: TKKeychain {
  public init() {}
  
  public func add(data: Data, query: TKKeychainQuery) throws {
    var query = query.query
    query[kSecValueData] = data as AnyObject
    
    let status = SecItemAdd(query as CFDictionary, nil)
    let keychainStatus = TKKeychainStatus(status: status)
    switch keychainStatus {
    case .success:
      return
    case .failure(let keychainError):
      throw keychainError
    }
  }
  
  public func get(query: TKKeychainQuery) throws -> Data? {
    var query = query.query
    query[kSecMatchLimit] = kSecMatchLimitOne
    query[kSecReturnData] = kCFBooleanTrue
    
    var result: AnyObject?
    let status = withUnsafeMutablePointer(to: &result) {
      SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
    }
    
    let keychainStatus = TKKeychainStatus(status: status)
    switch keychainStatus {
    case .success:
      return result as? Data
    case .failure(let keychainError):
      throw keychainError
    }
  }
  
  public func update(query: TKKeychainQuery, attributes: TKKeychainAttributes) throws {
    let status = SecItemUpdate(
      query.query as CFDictionary,
      attributes.attributes as CFDictionary
    )
    
    let keychainStatus = TKKeychainStatus(status: status)
    switch keychainStatus {
    case .success:
      return
    case .failure(let keychainError):
      throw keychainError
    }
  }
  
  public func delete(query: TKKeychainQuery) throws {
    let query = query.query
    let status = SecItemDelete(query as CFDictionary)
    
    let keychainStatus = TKKeychainStatus(status: status)
    switch keychainStatus {
    case .success:
      return
    case .failure(let keychainError):
      throw keychainError
    }
  }
}
