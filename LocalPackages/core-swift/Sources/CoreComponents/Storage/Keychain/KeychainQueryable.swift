import Foundation

public protocol KeychainQueryable {
  var query: [String: AnyObject] { get throws }
}
