import Foundation

public protocol AppInfoProvider {
  var version: String { get }
  var platform: String { get }
  var language: String { get }
  var storeCountryCode: String? { get }
  var deviceCountryCode: String? { get }
}
