import Foundation
import TKLogging

package class ConsoleAnalyticsLogger: AnalyticsService {
    private let logger = LogDomain.consoleAnalytics

    package init() {}

    package func logEvent(name: String, args: [String: Any]) {
        logger.i("🌠 Event logged: \(name), args: \(args)")
    }
}
