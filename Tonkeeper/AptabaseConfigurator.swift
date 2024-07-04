import Foundation
import Aptabase
import TKCore

public final class AptabaseConfigurator {
  
  static let configurator = AptabaseConfigurator()
  
  private init() {}
  
  public func configure() {
    Aptabase.shared.initialize(
      appKey: InfoProvider.aptabaseKey()!,
      with: InitOptions(host: InfoProvider.aptabaseEndpoint())
    )
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
