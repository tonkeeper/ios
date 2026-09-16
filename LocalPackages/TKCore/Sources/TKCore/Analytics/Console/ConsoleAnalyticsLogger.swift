import Foundation
import TKLogging

class ConsoleAnalyticsLogger: AnalyticsService {
    private let logger = LogDomain.consoleAnalytics

    init() {}

    func logEvent(name: String, args: [String: Any]) {
        logger.i("🌠 Event logged: \(name), args: \(args)")
    }
}
