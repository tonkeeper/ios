import Foundation

public protocol AppInfoProvider {
    var version: String { get }
    var userAgent: String { get }
    var platform: String { get }
    var language: String { get }
    var storeCountryCode: String? { get async }
    var deviceCountryCode: String? { get }
    var isVPNActive: Bool { get }
    var timeZoneIdentifier: String { get }
}
