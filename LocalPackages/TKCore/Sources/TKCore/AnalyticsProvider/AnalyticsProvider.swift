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
  func logEvent(eventKey: EventKeys)
  func logEvent(eventKey: EventKeys, args: [String: String])
}

public struct AnalyticsProvider {
  public var services: [AnalyticsService]
  
  public init(analyticsServices: AnalyticsService...) {
    self.services = analyticsServices
  }
  
  public func logEvent(eventKey: EventKeys) {
    for service in services {
      service.logEvent(eventKey: eventKey)
    }
  }
  
  public func logEvent(eventKey: EventKeys, args: [String: String]) {
    for service in services {
      service.logEvent(eventKey: eventKey, args: args)
    }
  }
}
