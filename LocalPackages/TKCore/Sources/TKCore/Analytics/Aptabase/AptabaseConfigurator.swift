import Foundation
import Aptabase

public final class AptabaseConfigurator {
  
  public static let configurator = AptabaseConfigurator()
  
  private init() {}
  
  public func configure() {
    Aptabase.shared.initialize(
      appKey: InfoProvider.aptabaseKey()!,
      with: InitOptions(host: InfoProvider.aptabaseEndpoint())
    )
  }
}

public class AptabaseService: AnalyticsService {
  
  public init() {}
  
  public func logEvent(eventKey: EventKeys, args: [String : String]) {
    Aptabase.shared.trackEvent(eventKey.rawValue, with: args)
  }
}
