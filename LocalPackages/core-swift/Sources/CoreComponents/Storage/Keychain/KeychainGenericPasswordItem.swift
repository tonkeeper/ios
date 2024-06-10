import Foundation

public struct KeychainGenericPasswordItem: KeychainQueryable {
  let service: String
  let account: String?
  let accessGroup: String?
  let accessible: KeychainAccessible
  let isBiometry: Bool
  
  public init(service: String,
              account: String?,
              accessGroup: String?,
              accessible: KeychainAccessible,
              isBiometry: Bool = false) {
    self.service = service
    self.account = account
    self.accessGroup = accessGroup
    self.accessible = accessible
    self.isBiometry = isBiometry
  }
  
  public var query: [String : AnyObject] {
    var query = [String: AnyObject]()
    query[kSecClass as String] = kSecClassGenericPassword
    query[kSecAttrService as String] = service as AnyObject
    if let account = account {
      query[kSecAttrAccount as String] = account as AnyObject
    }
    if let accessGroup = accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup as AnyObject
    }
    if isBiometry {
      let accessOptions = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        accessible.keychainKey,
        SecAccessControlCreateFlags.biometryCurrentSet,
        nil
      )
      query[kSecAttrAccessControl as String] = accessOptions
    } else {
      query[kSecAttrAccessible as String] = accessible.keychainKey
    }
    return query
  }
}
