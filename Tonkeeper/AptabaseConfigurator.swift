import Foundation
import Aptabase
import TKCore

public final class AptabaseConfigurator {
  
  static let configurator = AptabaseConfigurator()
  
  private init() {}
  
  public func configure() {
    Aptabase.shared.initialize(appKey: "A-SH-6199502298", with: InitOptions(host: "https://anonymous-analytics.tonkeeper.com"))
  }
}

public class AptabaseService: AnalyticsService {
  public func logEvent(eventKey: EventKeys) {
    Aptabase.shared.trackEvent(eventKey.rawValue)
  }
  
  public func logEvent(eventKey: EventKeys, args: [String : String]) {
    Aptabase.shared.trackEvent(eventKey.rawValue, with: args)
  }
}
