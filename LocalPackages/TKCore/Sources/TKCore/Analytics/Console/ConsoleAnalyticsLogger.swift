import Foundation

public class ConsoleAnalyticsLogger: AnalyticsService {
  
  public init() {}
  
  public func logEvent(eventKey: EventKey, args: [String : Any]) {
    print("🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵")
    print("🪵ConsoleAnalyticsLogger🪵")
    print("🪵Log event - \(eventKey.rawValue)🪵")
    print("🪵Parameters - \(args)🪵")
    print("🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵🪵")
  }
}
