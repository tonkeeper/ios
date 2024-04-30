import Foundation

public struct KeychainGenericPasswordItem: KeychainQueryable {
  let service: String
  let account: String?
  let accessGroup: String?
  let accessible: KeychainAccessible
  
  public init(service: String,
              account: String?,
              accessGroup: String?,
              accessible: KeychainAccessible) {
    self.service = service
    self.account = account
    self.accessGroup = accessGroup
    self.accessible = accessible
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
    query[kSecAttrAccessible as String] = accessible.keychainKey
    return query
  }
}
