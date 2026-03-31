import Foundation
import TKLogging

public class ConsoleAnalyticsLogger: AnalyticsService {
    private let logger = LogDomain.consoleAnalytics

    public init() {}

    public func logEvent(name: String, args: [String: Any]) {
        logger.i("🌠 Event logged: \(name), args: \(args)")
    }
}
