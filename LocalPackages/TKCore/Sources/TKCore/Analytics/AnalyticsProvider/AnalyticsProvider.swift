import Foundation
import Aptabase

public enum EventKeys: String {
  case clickDapp = "click_dapp"
  case launchApp = "launch_app"
  case importWallet = "import_wallet"
  case importWatchOnly = "import_watch_only"
  case generateWallet = "generate_wallet"
  case deleteWallet = "delete_wallet"
  case resetWallet = "reset_wallet"
  case openBrowser = "browser_open"
}

public protocol AnalyticsService {
  func logEvent(eventKey: EventKeys, args: [String: String])
}

public extension AnalyticsService {
  func logEvent(eventKey: EventKeys) {
    self.logEvent(eventKey: eventKey, args: [:])
  }
}

public struct AnalyticsProvider {
  private let services: [AnalyticsService]
  private let uniqueIdProvider: UniqueIdProvider
  
  public init(analyticsServices: AnalyticsService...,
              uniqueIdProvider: UniqueIdProvider) {
    self.services = analyticsServices
    self.uniqueIdProvider = uniqueIdProvider
  }
  
  public func logEvent(eventKey: EventKeys, args: [String: String] = [:]) {
    var args = args
    args["firebase_user_id"] = uniqueIdProvider.uniqueDeviceId.uuidString
    for service in services {
      service.logEvent(eventKey: eventKey, args: args)
    }
  }
}
