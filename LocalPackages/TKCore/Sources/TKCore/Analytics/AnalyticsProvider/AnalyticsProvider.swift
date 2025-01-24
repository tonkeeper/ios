import Foundation
import Aptabase

public enum EventKey: String {
  case firstLaunch = "first_launch"
  case clickDapp = "click_dapp"
  case launchApp = "launch_app"
  case importWallet = "import_wallet"
  case importWatchOnly = "import_watch_only"
  case generateWallet = "generate_wallet"
  case deleteWallet = "delete_wallet"
  case resetWallet = "reset_wallet"
  case openBrowser = "browser_open"
  
  case storyOpen = "story_open"
  case storyPageView = "story_page_view"
  case storyClick = "story_click"
  
  case pushClick = "push_click"
  
  public var parameters: [String : Any] { [:] }
  public var key: String { rawValue }
}

public protocol AnalyticsService {
  func logEvent(eventKey: EventKey, args: [String: Any])
}

public extension AnalyticsService {
  func logEvent(eventKey: EventKey) {
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
  
  public func logEvent(eventKey: EventKey, args: [String: Any] = [:]) {
    var args = args
    args["firebase_user_id"] = uniqueIdProvider.uniqueDeviceId.uuidString
    for service in services {
      service.logEvent(eventKey: eventKey, args: args)
    }
  }
}
